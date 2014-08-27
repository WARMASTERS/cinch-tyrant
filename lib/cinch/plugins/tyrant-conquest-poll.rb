require 'cinch'
require 'cinch/tyrant/cmd'
require 'cinch/plugins/tyrant-conquest'
require 'set'
require 'tyrant'
require 'tyrant/cards'
require 'tyrant/conquest'
require 'tyrant/sanitize'

module Cinch; module Plugins; class TyrantConquestPoll
  include Cinch::Plugin

  POLL_INTERVAL = 60
  INVASION_POLL_INTERVAL = 15

  DEFAULTS_TILES = {
    :invasion_start => true,
    :invasion_win => true,
    :invasion_loss => true,
    :defense_start => true,
    :defense_win => true,
    :defense_loss => true,
    :map_reset => true,
  }

  DEFAULTS_INVASION = {
    :monitor => true,
    :commander_switch => true,
    :slot_killed => true,
    :cset_feedback => true,
    :claim_feedback => true,
    :free_feedback => true,
    :stuck_feedback => true,
    :check_feedback => true,
    :status_feedback => true,
  }

  timer POLL_INTERVAL, method: :check_conquest
  timer INVASION_POLL_INTERVAL, method: :check_invasion

  match(/tilenews\s*(\S+)\s*(\S+)?/i, method: :tilenews)
  match(/invasionnews\s*(\S+)\s*(\S+)?/i, method: :invasionnews)
  match(/ctrack(.*)/i, method: :ctrack)

  COMMANDS = [
    Cinch::Tyrant::Cmd.new('conquest', 'tilenews', 'list',
      lambda { |m| is_officer?(m) },
      'Lists possible conquest news alert items'
    ),
    Cinch::Tyrant::Cmd.new('conquest', 'tilenews', '<item> <on|off>',
      lambda { |m| is_officer?(m) },
      'Turns a conquest news item (from !tilenews list) on or off'
    ),
    Cinch::Tyrant::Cmd.new('invasion', 'invasionnews', 'list',
      lambda { |m| is_officer?(m) },
      'Lists possible invasion news alert items'
    ),
    Cinch::Tyrant::Cmd.new('invasion', 'invasionnews', '<item> <on|off>',
      lambda { |m| is_officer?(m) },
      'Turns a invasion news item (from !invasionnews list) on or off'
    ),
  ]

  Struct.new('Slot', :commander, :hp, :defeated,
             :attackers, :stuck,
             :owner,
             :deck, :deck_set_by, :deck_set_time,
             :hash,
             :original_format,
             :change_time) {
    def known?
      self.deck && (!self.change_time || self.change_time < self.deck_set_time)
    end

    def list_stuck
      self.stuck.to_a.map { |x|
        TyrantConquest::safe_name(x)
      }.join(', ')
    end

    def list_attackers
      self.attackers.to_a.map { |x|
        TyrantConquest::safe_name(x)
      }.join(', ')
    end
  }

  class MonitoredTiles
    def initialize(faction_id, options_by_channel)
      @faction_id = faction_id
      @options_by_channel = options_by_channel
    end

    def channels_for(sym)
      return @options_by_channel.select { |_, v| v[sym] }.keys
    end
  end

  class MonitoredInvasion
    include Cinch::Helpers

    attr_reader :tyrant
    attr_reader :invasion_tile, :invasion_info
    attr_reader :invasion_start_time, :invasion_end_time
    attr_reader :invasion_effect
    attr_reader :last_check
    attr_reader :max_hp
    attr_reader :slots_alive
    attr_reader :opponent

    def initialize(tyrant, options_by_channel)
      @tyrant = tyrant
      @options_by_channel = options_by_channel

      @invasion_tile = nil
      @new_invasion = false
      @invasion_info = Hash.new { |h, k|
        h[k] = Struct::Slot.new(1000, 100, false, Set.new, Set.new)
      }
      @invasion_start_time = nil
      @invasion_end_time = nil
      @last_check = nil
      @max_hp = '??'
      @slots_alive = nil
      @opponent = nil
    end

    def invasion_tile=(t)
      return if @invasion_tile == t
      @invasion_tile = t
      @new_invasion = true
      @invasion_info.clear if t
    end

    def check_invasion
      return [] if @tyrant.nil?
      return [] if !@invasion_tile

      json = @tyrant.make_request('getConquestTileInfo',
                                  "system_id=#{@invasion_tile}", reinit: false)
      messages = Hash.new { |h, k| h[k] = [] }

      return [] if json['duplicate_client']

      @max_hp = json['system']['max_health']
      @opponent = json['system']['faction_id']
      @slots_alive = 0

      json['system']['slots'].each{ |k, v|
        # Only notify if ongoing invasion
        unless @new_invasion
          if v['defeated'] == '1' && !@invasion_info[k][:defeated]
            # Defeated! Notify channel if requested
            push_messages(messages, :slot_killed) {
              c = TyrantConquestPoll::cards
              name = c[v['commander_id'].to_i % 10000].name
              name = 'Foil ' + name if v['commander_id'].to_i > 10000
              message = "[INVASION] Slot #{k} (#{name}) has been defeated!"
              unless @invasion_info[k].stuck.empty?
                stuck_people = @invasion_info[k].stuck.to_a.join(', ')
                message += ' ' + stuck_people + ': you are free!'
              end
              message
            }

            # Since it's dead nobody is stuck or attacking anymore
            @invasion_info[k].attackers.clear
            @invasion_info[k].stuck.clear
          elsif @invasion_info[k][:commander] != v['commander_id']
            # Commander has changed!
            @invasion_info[k][:change_time] = Time.now.to_i

            # Notify channel if requested
            push_messages(messages, :commander_switch) {
              c = TyrantConquestPoll::cards
              name1 = c[@invasion_info[k][:commander].to_i % 10000].name
              name1 = 'Foil ' + name1 if @invasion_info[k][:commander].to_i > 10000
              name2 = c[v['commander_id'].to_i % 10000].name
              name2 = 'Foil ' + name2 if v['commander_id'].to_i > 10000
              hp = v['health']
              message = "[INVASION] Slot #{k} (#{hp} HP) commander changed from #{name1} to #{name2}"
              unless @invasion_info[k].attackers.empty?
                attackers = @invasion_info[k].attackers.to_a.join(', ')
                message += ' ' + attackers + ': be careful!'
              end
              message
            }
          end
        end
        @invasion_info[k][:commander] = v['commander_id']
        @invasion_info[k][:hp] = v['health']
        @invasion_info[k][:defeated] = v['defeated'] == '1'
        @slots_alive += 1 if v['defeated'] != '1'
      }

      @new_invasion = @invasion_tile.nil?
      @invasion_start_time = json['system']['attack_start_time'].to_i
      @invasion_end_time = json['system']['attack_end_time'].to_i
      @invasion_effect = json['system']['effect']
      @invasion_effect &&= @invasion_effect.to_i
      @last_check = Time.now.to_i
      messages
    end

    def option_enabled?(channel_name, option_sym)
      opts = @options_by_channel[channel_name.downcase]
      return nil if !opts
      return opts[option_sym]
    end

    def monitor_enabled?
      return @options_by_channel.values.any? { |v| v[:monitor] }
    end

    private

    def push_messages(messages, sym)
      channels = @options_by_channel.select { |_, v| v[sym] }.keys
      return if channels.empty?
      message = yield
      channels.each { |c| messages[c] << message }
    end
  end

  @cards = {}
  @report_channel = nil
  class << self
    attr_accessor :cards
    attr_accessor :report_channel
  end

  def setup(faction_store, config_store, sym, defaults, faction)
    channels = faction.channel_for(sym)
    channels = [channels] unless channels.is_a?(Array)

    channel_configs = config[:channels] || {}
    configs = channels.map { |c|
      [c.downcase, channel_configs[c] || defaults.dup]
    }.to_h
    config_store.merge!(configs)

    monitored_faction = yield configs
    faction_store[faction.id] = monitored_faction
  end

  def initialize(*args)
    super
    @tiles_by_id = {}
    @invasions_by_id = {}
    @invasions_by_channel = {}
    shared[:conquest_factions] = @invasions_by_channel
    @poller = Tyrants.get(config[:poller])
    @map_json = @poller.make_request('getConquestMap')
    @map_hash = {}
    @map_json['conquest_map']['map'].each { |t| @map_hash[t['system_id']] = t }
    shared[:conquest_map_hash] = @map_hash
    @ctrack_enabled = true
    @reset_acknowledged = false

    @invasion_configs = {}
    @tiles_configs = {}

    self.class.cards = shared[:cards_by_id]
    self.class.report_channel = config[:report_channel]

    BOT_FACTIONS.each { |faction|
      next if faction.id < 0

      setup(@tiles_by_id, @tiles_configs, :tiles, DEFAULTS_TILES,
            faction) { |*conf|
        MonitoredTiles.new(faction.id, *conf)
      }

      next unless faction.player

      setup(@invasions_by_id, @invasion_configs, :invasion, DEFAULTS_INVASION,
            faction) { |*conf|
        MonitoredInvasion.new(Tyrants.get(faction.player), *conf)
      }
      faction.channels.each { |chan|
        @invasions_by_channel[chan.downcase] = @invasions_by_id[faction.id]
      }
    }

    @map_hash.each { |id, t|
      current_attacker = t['attacking_faction_id'].to_i
      if current_attacker != 0
        if f = @invasions_by_id[current_attacker]
          f.invasion_tile = id
        end
      end
    }
  end

  def send_message(faction, tile, verb, enemy, enable_sym)
    channel_names = faction.channels_for(enable_sym)
    channel_names.each { |cn|
      Channel(cn).send(['[CONQUEST]', tile, verb, enemy].compact.join(' '))
    }
  end

  def check_invasion
    @invasions_by_id.each_value { |faction|
      next unless faction.monitor_enabled?
      messages = faction.check_invasion
      messages.each { |channel_name, msgs|
        channel = Channel(channel_name)
        msgs.each { |m| channel.send(m) }
      }
    }
  end

  def check_conquest
    @map_json = @poller.make_request('getConquestMap')

    tiles_owned = @map_json['conquest_map']['map'].count { |t|
      t['faction_id']
    }

    if tiles_owned == 0
      if !@reset_acknowledged
        @tiles_by_id.each_value { |faction|
          send_message(faction, nil, 'MAP RESET!!!', nil, :map_reset)
        }
        Channel(self.class.report_channel).send("[CONQUEST] MAP RESET!!!")
      end
      @reset_acknowledged = true

      @map_json['conquest_map']['map'].each { |t|
        @map_hash[t['system_id']] = t
      }

      return
    end

    @reset_acknowledged = false

    no_attack_factions = Set.new(@invasions_by_id.keys)

    @map_json['conquest_map']['map'].each { |t|
      id = t['system_id']
      prev_t = @map_hash[id]
      @map_hash[id] = t

      # Premature optimization?
      # Don't calculate these unless necessary,
      # but also don't calculate them more than once
      name = nil
      prefix = nil

      current_owner = t['faction_id'].to_i
      old_owner = prev_t['faction_id'].to_i
      if old_owner != current_owner
        name ||= TyrantConquest::tile_name(t)
        prefix ||= '[CONQUEST] ' + name + ' '

        current = ::Tyrant::sanitize_or_default(t['faction_name'], '(neutral)')
        old = ::Tyrant::sanitize_or_default(prev_t['faction_name'], '(neutral)')

        if @ctrack_enabled
          o = "#{old}[#{old_owner.to_i}]"
          c = "#{current}[#{current_owner.to_i}]"
          message = "#{prefix}#{o} -> #{c}"
          Channel(self.class.report_channel).send(message)
        end

        if f = @tiles_by_id[current_owner]
          send_message(f, name, 'Conquered from', old, :invasion_win)
        end
        if f = @tiles_by_id[old_owner]
          send_message(f, name, 'Lost to', current, :defense_loss)
        end
      end

      current_attacker = t['attacking_faction_id'].to_i
      old_attacker = prev_t['attacking_faction_id'].to_i
      if old_attacker != current_attacker
        name ||= TyrantConquest::tile_name(t)
        prefix ||= '[CONQUEST] ' + name + ' '

        owner = ::Tyrant::sanitize_or_default(t['faction_name'], '(neutral)')
        if old_attacker != 0 && old_attacker != current_owner
          attacker = ::Tyrant::sanitize_or_default(
            prev_t['attacking_faction_name'], '(nil)'
          )

          if @ctrack_enabled
            o = "#{owner}[#{current_owner.to_i}]"
            a = "#{attacker}[#{old_attacker.to_i}]"
            message = "#{prefix}#{o} holds off #{a}"
            Channel(self.class.report_channel).send(message)
          end

          if f = @tiles_by_id[current_owner]
            send_message(f, name, 'Defended against', attacker, :defense_win)
          end
          if f = @tiles_by_id[old_attacker]
            send_message(f, name, 'Failed invasion against', owner,
                         :invasion_loss)
          end
        end
        if current_attacker != 0
          attacker = ::Tyrant::sanitize_or_default(
            t['attacking_faction_name'], '(nil)'
          )

          if @ctrack_enabled
            o = "#{owner}[#{current_owner.to_i}]"
            a = "#{attacker}[#{current_attacker.to_i}]"
            message = "#{prefix}#{o} invaded by #{a}"
            Channel(self.class.report_channel).send(message)
          end

          if f = @tiles_by_id[current_owner]
            send_message(f, name, 'Under attack by', attacker, :defense_start)
          end
          if f = @tiles_by_id[current_attacker]
            send_message(f, name, 'New invasion against', owner, :invasion_start)
          end
          if f = @invasions_by_id[current_attacker]
            f.invasion_tile = id
          end
        end
      end

      no_attack_factions.delete(current_attacker) if current_attacker != 0
    }

    no_attack_factions.each { |x| @invasions_by_id[x].invasion_tile = nil }
  end

  def tilenews(m, option, switch)
    news(m, @tiles_configs, 'tile', option, switch)
  end
  def invasionnews(m, option, switch)
    news(m, @invasion_configs, 'invasion', option, switch)
  end

  def news(m, hash, name, option, switch)
    return unless is_officer?(m)

    opts = hash[m.channel.name.downcase]

    if option.downcase == 'list'
      m.reply(opts.to_s)
      return
    end

    if option.downcase == '*'
      if switch == 'on'
        new_state = true
        m.reply("Setting all #{name} news items on")
      elsif switch == 'off'
        new_state = false
        m.reply("Setting all #{name} news items off")
      else
        m.reply("wat? #{m.user.name} smells")
        return
      end
      opts.keys.each { |k| opts[k] = new_state unless k == :monitor }
      return
    end

    option_sym = option.to_sym

    if !opts.has_key?(option_sym)
      m.reply("#{option} is not a valid #{name} news item")
      return
    end

    msg = "#{option} was #{opts[option_sym] ? 'on' : 'off'}"

    if switch == 'on'
      opts[option_sym] = true
      m.reply(msg + ", and now it is on")
    elsif switch == 'off'
      opts[option_sym] = false
      m.reply(msg + ", and now it is off")
    else
      m.reply(msg + ", and it is staying that way")
    end
  end

  def ctrack(m, switch)
    return unless m.user.master?

    msg = "Conquest track was #{@ctrack_enabled ? 'on' : 'off'}"

    if switch == ' on'
      @ctrack_enabled = true
      m.reply(msg + ", and now it is on")
    elsif switch == ' off'
      @ctrack_enabled = false
      m.reply(msg + ", and now it is off")
    else
      m.reply(msg + ", and it is staying that way")
    end
  end
end; end; end
