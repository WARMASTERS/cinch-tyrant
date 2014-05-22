require 'cinch'
require 'cinch/tyrant/cmd'
require 'tyrant/faction'

module Cinch; module Plugins; class TyrantPoll
  include Cinch::Plugin

  # Give me time to login: Allow up to this many tries before reinit.
  RETRIES = 1

  DEFAULT_SETTINGS = [true, 1]

  class MonitoredFaction
    attr_accessor :monitor
    attr_reader :user, :tyrant

    def initialize(user, monitor, multiplier)
      @user = user
      @tyrant = Tyrants.get(user)
      @monitor = monitor
      @multiplier = multiplier
      @count = 1
      @fail_count = 0
    end

    def faction_id; @tyrant.faction_id; end

    def check
      return if not @monitor
      @count += 1
      return if @count % @multiplier != 0

      reinit = @fail_count > RETRIES
      json = @tyrant.make_request(poll_name, poll_params, reinit: reinit)

      if json['duplicate_client'] == 1
        # Decrement count so next time @count % @multiplier == 0 still
        @count -= 1
        @fail_count += 1
        return
      else
        @fail_count = 0
      end

      poll_result(json)
    end
  end

  def monitored_faction
    MonitoredFaction
  end

  def initialize(*args)
    super
    @factions = {}

    channel_configs = config[:channels] || {}

    BOT_FACTIONS.each { |faction|
      next if faction.id < 0 || faction.player.nil?
      channel = faction.channel_for(notification_type)
      args = channel_configs[channel] || DEFAULT_SETTINGS
      @factions[channel] = monitored_faction.new(faction.player, *args)
    }
  end

  def check_all
    @factions.each { |channel, faction|
      notify(channel, faction, faction.check)
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
    else
      m.reply(msg + ", and it is staying that way")
    end
  end
end; end; end
