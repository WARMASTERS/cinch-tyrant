require 'cinch'
require 'cinch/tyrant/cmd'
require 'tyrant/faction'

module Cinch; module Plugins; class TyrantFactionChat
  include Cinch::Plugin

  # Give me time to login: Allow up to this many tries before reinit.
  RETRIES = 1

  DEFAULT_SETTINGS = [true, 1]

  timer 60, method: :check_all

  match(/chat(.*)/i)

  COMMANDS = [
    Cinch::Tyrant::Cmd.new('chat', 'chat', '<on|off>',
      lambda { |m| is_officer?(m) },
      'Turns faction chat monitor on/off. ' +
      'Faction chat is relayed into the channel every minute if enabled.'
    ),
  ]

  class MonitoredFaction
    attr_accessor :monitor
    attr_reader :last
    attr_reader :user

    def initialize(user, monitor, multiplier)
      @user = user
      @tyrant = Tyrants.get(user)
      messages = @tyrant.get_faction_chat
      @last = messages[-1] ? messages[-1]['post_id'] : nil
      @monitor = monitor
      @multiplier = multiplier
      @count = 1
      @fail_count = 0
    end

    def faction_id
      @tyrant.faction_id
    end

    def check
      return if not @monitor
      @count += 1
      return if @count % @multiplier != 0

      if @last
        p = "last_post=#{@last}"

        reinit = @fail_count > RETRIES
        json = @tyrant.make_request('getNewFactionMessages', p, reinit: reinit)

        if json['duplicate_client'] == 1
          # Decrement count so next time @count % @multiplier == 0 still
          @count -= 1
          @fail_count += 1
          return
        else
          @fail_count = 0
        end

        new_messages = json['messages']
      else
        new_messages = @tyrant.get_faction_chat
      end
      @last = new_messages[-1]['post_id'] unless new_messages.empty?
      new_messages
    end
  end

  def initialize(*args)
    super
    @factions = {}
    shared[:last_faction_chat] = Hash.new

    channel_configs = config[:channels] || {}

    BOT_FACTIONS.each { |faction|
      next if faction.id < 0 || faction.player.nil?
      channel = faction.channel_for(:faction_chat)
      args = channel_configs[channel] || DEFAULT_SETTINGS
      @factions[channel] = MonitoredFaction.new(faction.player, *args)
      shared[:last_faction_chat][faction.id] = @factions[channel].last
    }
  end

  REGISTRATION_MESSAGE = /^#{BOT_NICK}\s+confirm\s+(\w+)\s+(\w+)$/i

  def check_chat(channel, faction)
    new_messages = faction.check
    return if new_messages.nil?
    new_messages.each { |m|
      user = ::Tyrant.get_name_of_id(m['user_id'])

      msg = "[FACTION] #{user}: #{m['message'] ? m['message'].sanitize : 'nil'}"
      Channel(channel).send(msg)

      if (match = REGISTRATION_MESSAGE.match(m['message']))
        # TODO: Have this update the cache?
        tyrant = Tyrants.get(faction.user)
        members = tyrant.get_faction_members
        perm = members[m['user_id'].to_s]['permission_level'].to_i
        level = Cinch::Tyrant::Auth::DEFAULT_PERMISSIONS[perm]
        nick = match[1]
        code = match[2]
        success = Cinch::Tyrant::Auth::confirm_register(
          faction.faction_id, m['user_id'].to_i, nick, level, code
        )
        Channel(channel).send(nick + ': Thank you for registering.') if success
      end
    }
    shared[:last_faction_chat][faction.faction_id] = faction.last
  end

  def check_all
    @factions.each { |channel, faction|
      check_chat(channel, faction)
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
