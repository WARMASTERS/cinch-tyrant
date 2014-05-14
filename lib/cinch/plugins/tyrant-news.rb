require 'cinch'
require 'cinch/tyrant/cmd'
require 'set'
require 'tyrant/faction'
require 'tyrant/war'

module Cinch; module Plugins; class TyrantNews
  include Cinch::Plugin

  # Give me time to login: Allow up to this many tries before reinit.
  RETRIES = 1

  POLL_INTERVAL = 60

  DEFAULT_SETTINGS = [true, 1]

  timer POLL_INTERVAL, method: :check_news

  match(/news(.*)/i)

  COMMANDS = [
    Cinch::Tyrant::Cmd.new('war', 'news', '<on|off>',
      lambda { |m| is_officer?(m) },
      'Turns war monitor on/off. ' +
      'New wars are announced in channel every minute if enabled.'
    ),
  ]

  class MonitoredFaction
    attr_accessor :monitor

    def initialize(user, monitor, multiplier)
      @tyrant = Tyrants.get(user)
      @monitor = monitor
      @count = 0
      @fail_count = 0
      @multiplier = multiplier
      @acked_wars = Set.new
      @pending_finished_wars = Set.new

      wars = @tyrant.make_request('getActiveFactionWars')['wars']
      wars.each { |id, _| @acked_wars.add(id) }
    end

    # Returns [[json of new wars], [json of finished wars]]
    def check
      return [[], []] if not @monitor
      @count += 1
      return [[], []] if @count % @multiplier != 0

      current_wars = Set.new

      reinit = @fail_count > RETRIES
      json = @tyrant.make_request('getActiveFactionWars', reinit: reinit)
      if json['duplicate_client'] == 1
        # Decrement count so next time @count % @multiplier == 0 still
        @count -= 1
        @fail_count += 1
        return [[], []]
      else
        @fail_count = 0
      end

      wars = json['wars']
      wars.each { |id, _| current_wars.add(id) }

      current_not_acked = current_wars - @acked_wars
      acked_not_current = @acked_wars - current_wars
      @acked_wars = current_wars
      new_wars = []
      current_not_acked.each { |id| new_wars.push(wars[id]) }
      acked_not_current.each { |id| @pending_finished_wars.add(id) }

      return [new_wars, []] if @pending_finished_wars.empty?

      finished_wars = []

      @pending_finished_wars.each { |war_id|
        json = @tyrant.make_request('getFactionWarInfo',
                                    "faction_war_id=#{war_id}")
        finished_wars << json if json['completed'].to_i == 1
      }

      # Could I move this up?
      # Don't really want to modify set while iterating over it.
      finished_wars.each { |war|
        @pending_finished_wars.delete(war['faction_war_id'])
      }

      [new_wars, finished_wars]
    end

    def faction_id
      @tyrant.faction_id
    end

    def format(war)
      @tyrant.format_wars([war])
    end

    def pending_wars
      @pending_finished_wars.size
    end
  end


  def initialize(*args)
    super
    @factions = {}

    channel_configs = config[:channels] || {}

    BOT_FACTIONS.each { |faction|
      next if faction.id < 0 || faction.player.nil?
      channel = faction.channel_for(:wars)
      args = channel_configs[channel] || DEFAULT_SETTINGS
      @factions[channel] = MonitoredFaction.new(faction.player, *args)
    }
  end

  def check_news
    @factions.each { |channel, faction|
      new_wars, finished_wars = faction.check
      finished_wars.reverse.each { |war|
        # Since we're using getFactionWarInfo, we don't get 'victory' anymore :(
        defense = war['defender_faction_id'].to_i == faction.faction_id
        our_score = defense ? war['defender_points'] : war['attacker_points']
        our_score = our_score.to_i
        their_score = defense ? war['attacker_points'] : war['defender_points']
        their_score = their_score.to_i
        we_win = our_score > their_score || defense && our_score == their_score

        prefix = we_win ? 'VICTORY!!!' : 'Defeat!!!'
        Channel(channel).send("[WAR] #{prefix} #{faction.format(war)}")
      }
      new_wars.each { |war|
        defense_war = war['defender_faction_id'].to_i == faction.faction_id
        prefix = defense_war ? 'ALARUM!!! DEFENSE WAR!!!' : 'WAR UP!!!'
        Channel(channel).send("[WAR] #{prefix} #{faction.format(war)}")
      }
    }
  end

  def execute(m, switch)
    user_good = is_officer?(m)
    channel_good = @factions.keys.include?(m.channel.name)
    return unless user_good && channel_good

    faction = @factions[m.channel.name]

    msg = "Monitoring was #{faction.monitor ? 'on' : 'off'}"

    if switch == ' on'
      faction.monitor = true
      m.reply(msg + ", and now it is on")
    elsif switch == ' off'
      faction.monitor = false
      m.reply(msg + ", and now it is off")
    elsif switch == ' debug' && m.user.master?
      m.reply(msg + ", and this faction has #{faction.pending_wars} pending wars")
    else
      m.reply(msg + ", and it is staying that way")
    end
  end
end; end; end
