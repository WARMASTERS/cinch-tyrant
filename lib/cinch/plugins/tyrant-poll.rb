require 'cinch'
require 'cinch/tyrant/cmd'
require 'tyrant/faction'

module Cinch; module Plugins; class TyrantPoll
  include Cinch::Plugin

  # Give me time to login: Allow up to this many tries before reinit.
  RETRIES = 1

  DEFAULT_SETTINGS = [true, 1]

  class MonitoredFaction
    attr_reader :user, :tyrant, :channels

    def initialize(user, channels)
      @user = user
      @tyrant = Tyrants.get(user)
      @channels = channels
      @count = 1
      @fail_count = 0
    end

    def faction_id; @tyrant.faction_id; end

    def check
      @count += 1
      channels_who_care = @channels.to_a.select { |chan, a|
        enabled, interval = a
        enabled && @count % interval == 0
      }.map { |chan, a| chan }
      return [[], nil] if channels_who_care.empty?

      reinit = @fail_count > RETRIES
      json = @tyrant.make_request(poll_name, poll_params, reinit: reinit)

      if json['duplicate_client'] == 1
        # Decrement count so next time @count % @multiplier == 0 still
        @count -= 1
        @fail_count += 1
        return [[], nil]
      else
        @fail_count = 0
      end

      # Notify all channels, regardless of who caused the poll.
      # Otherwise, some channels miss messages.
      [@channels.keys, poll_result(json)]
    end
  end

  def monitored_faction
    MonitoredFaction
  end

  def initialize(*args)
    super
    @factions = {}
    @channels = {}

    channel_configs = config[:channels] || {}

    BOT_FACTIONS.each { |faction|
      next if faction.id < 0 || faction.player.nil?
      channels = faction.channel_for(notification_type)
      channels = [channels] unless channels.is_a?(Array)

      configs = channels.map { |c|
        [c, channel_configs[c] || DEFAULT_SETTINGS.dup]
      }.to_h
      mf = monitored_faction.new(faction.player, configs)
      @factions[faction.id] = mf
      channels.each { |c| @channels[c] = mf }
    }
  end

  def check_all
    @factions.each { |channel, faction|
      channels_who_care, data = faction.check
      next if channels_who_care.empty?
      notify(faction, channels_who_care, data)
    }
  end

  def execute(m, switch)
    user_good = is_officer?(m)
    channel_good = @channels.has_key?(m.channel.name)
    return unless user_good && channel_good

    faction = @channels[m.channel.name].channels[m.channel.name]

    msg = "Monitoring was #{faction[0] ? 'on' : 'off'}"

    if switch == ' on'
      faction[0] = true
      m.reply(msg + ", and now it is on")
    elsif switch == ' off'
      faction[0] = false
      m.reply(msg + ", and now it is off")
    else
      m.reply(msg + ", and it is staying that way")
    end
  end
end; end; end
