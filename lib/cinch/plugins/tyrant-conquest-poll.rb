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

  CLEM_CONFLICT = [
    :invasion_switch,
    :invasion_kill,
    :cset_feedback,
    :claim_feedback,
    :free_feedback,
    :stuck_feedback,
    :check_feedback,
    :status_feedback,
  ]

  DEFAULT_SETTINGS = {
    :invasion_start => true,
    :invasion_win => true,
    :invasion_loss => true,
    :invasion_monitor => true,
    :invasion_switch => true,
    :invasion_kill => true,
    :defense_start => true,
    :defense_win => true,
    :defense_loss => true,
    :cset_feedback => true,
    :claim_feedback => true,
    :free_feedback => true,
    :stuck_feedback => true,
    :check_feedback => true,
    :status_feedback => true,
  }

  timer POLL_INTERVAL, method: :check_conquest
  timer INVASION_POLL_INTERVAL, method: :check_invasion

  match(/cnews\s*(\S+)\s*(\S+)?/i, method: :cnews)
  match(/ctrack(.*)/i, method: :ctrack)

  COMMANDS = [
    Cinch::Tyrant::Cmd.new('conquest', 'cnews', 'list',
      lambda { |m| is_warmaster?(m) },
      'Lists possible conquest news alert items'
    ),
    Cinch::Tyrant::Cmd.new('conquest', 'cnews', '<item> <on|off>',
      lambda { |m| is_warmaster?(m) },
      'Turns a conquest news item (from !cnews list) on or off'
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


  class MonitoredFaction
    include Cinch::Helpers

    attr_accessor :monitor_opts
    attr_reader :tyrant
    attr_reader :channel
    attr_reader :invasion_tile, :invasion_info
    attr_reader :invasion_start_time, :invasion_end_time
    attr_reader :invasion_effect
    attr_reader :last_check
    attr_reader :max_hp
    attr_reader :slots_alive
    attr_reader :opponent

    def initialize(tyrant, faction_id, channel, monitor_opts)
      @tyrant = tyrant
      @faction_id = faction_id
      @channel = channel
      @monitor_opts = monitor_opts

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
      messages = []

      return [] if json['duplicate_client']

      @max_hp = json['system']['max_health']
      @opponent = json['system']['faction_id']
      @slots_alive = 0

      json['system']['slots'].each{ |k, v|
        # Only notify if ongoing invasion
        unless @new_invasion
          if v['defeated'] == '1' && !@invasion_info[k][:defeated]
            # Defeated! Notify channel if requested
            if @monitor_opts[:invasion_kill]
              c = TyrantConquestPoll::cards
              name = c[v['commander_id'].to_i % 10000].name
              name = 'Foil ' + name if v['commander_id'].to_i > 10000
              message = "[INVASION] Slot #{k} (#{name}) has been defeated!"
              unless @invasion_info[k].stuck.empty?
                stuck_people = @invasion_info[k].stuck.to_a.join(', ')
                message += ' ' + stuck_people + ': you are free!'
              end
              messages.push(message)
            end

            # Since it's dead nobody is stuck or attacking anymore
            @invasion_info[k].attackers.clear
            @invasion_info[k].stuck.clear
          elsif @invasion_info[k][:commander] != v['commander_id']
            # Commander has changed!
            @invasion_info[k][:change_time] = Time.now.to_i

            # Notify channel if requested
            if @monitor_opts[:invasion_switch]
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
              messages.push(message)
            end
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
  end

  @cards = {}
  @report_channel = nil
  class << self
    attr_accessor :cards
    attr_accessor :report_channel
  end

  def initialize(*args)
    super
    @factions_by_id = {}
    @all_factions = {}
    shared[:conquest_factions] = @all_factions
    @poller = Tyrants.get(config[:poller])
    @map_json = @poller.make_request('getConquestMap')
    @map_hash = {}
    @map_json['conquest_map']['map'].each { |t| @map_hash[t['system_id']] = t }
    shared[:conquest_map_hash] = @map_hash
    @ctrack_enabled = true
    @reset_acknowledged = false

    self.class.cards = shared[:cards_by_id]
    self.class.report_channel = config[:report_channel]

    channel_configs = config[:channels] || {}

    BOT_FACTIONS.each { |faction|
      next if faction.id < 0
      channel = faction.channel_for(:conquest)
      args = DEFAULT_SETTINGS.merge(channel_configs[channel] || {})
      tyrant = faction.player ? Tyrants.get(faction.player) : nil
      monitored_faction = MonitoredFaction.new(
        tyrant, faction.id, channel, args
      )
      @factions_by_id[faction.id] = monitored_faction
      faction.channels.each { |chan|
        @all_factions[chan] = monitored_faction
      }
    }

    @map_hash.each { |id, t|
      current_attacker = t['attacking_faction_id'].to_i
      if current_attacker != 0
        if f = @factions_by_id[current_attacker]
          f.invasion_tile = id
        end
      end
    }
  end

  def send_message(faction, tile, verb, enemy, enable_sym)
    return unless faction.monitor_opts[enable_sym]
    prefix = '[CONQUEST] '
    Channel(faction.channel).send(prefix + tile + " #{verb} #{enemy}")
  end

  def check_invasion
    @factions_by_id.each_value { |faction|
      next unless faction.monitor_opts[:invasion_monitor]
      messages = faction.check_invasion
      messages.each { |m| Channel(faction.channel).send(m) }
    }
  end

  def check_conquest
    @map_json = @poller.make_request('getConquestMap')

    tiles_owned = @map_json['conquest_map']['map'].count { |t|
      t['faction_id']
    }

    if tiles_owned == 0
      if !@reset_acknowledged
        @factions_by_id.each_value { |faction|
          Channel(faction.channel).send("[CONQUEST] MAP RESET!!!")
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

    no_attack_factions = Set.new(@factions_by_id.keys)

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

        if f = @factions_by_id[current_owner]
          send_message(f, name, 'Conquered from', old, :invasion_win)
        end
        if f = @factions_by_id[old_owner]
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

          if f = @factions_by_id[current_owner]
            send_message(f, name, 'Defended against', attacker, :defense_win)
          end
          if f = @factions_by_id[old_attacker]
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

          if f = @factions_by_id[current_owner]
            send_message(f, name, 'Under attack by', attacker, :defense_start)
          end
          if f = @factions_by_id[current_attacker]
            f.invasion_tile = id
            send_message(f, name, 'New invasion against', owner, :invasion_start)
          end
        end
      end

      no_attack_factions.delete(current_attacker) if current_attacker != 0
    }

    no_attack_factions.each { |x| @factions_by_id[x].invasion_tile = nil }
  end

  def cnews(m, option, switch)
    return unless is_warmaster?(m)

    faction = @all_factions[m.channel.name]

    if option.downcase == 'list'
      m.reply(faction.monitor_opts.to_s)
      return
    end

    if option.downcase == 'clem'
      if switch == 'on'
        new_state = true
        m.reply('Setting all clemmy commands on')
      elsif switch == 'off'
        new_state = false
        m.reply('Setting all clemmy commands off')
      else
        m.reply("wat? #{m.user.name} smells")
        return
      end
      CLEM_CONFLICT.each { |s| faction.monitor_opts[s] = new_state }
      return
    end

    option_sym = option.to_sym

    if !faction.monitor_opts.has_key?(option_sym)
      m.reply("#{option} is not a valid conquest news item")
      return
    end

    msg = "#{option} was #{faction.monitor_opts[option_sym] ? 'on' : 'off'}"

    if switch == 'on'
      faction.monitor_opts[option_sym] = true
      m.reply(msg + ", and now it is on")
    elsif switch == 'off'
      faction.monitor_opts[option_sym] = false
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
