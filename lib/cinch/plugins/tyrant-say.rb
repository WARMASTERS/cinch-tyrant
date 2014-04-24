require 'cgi'
require 'cinch'
require 'cinch/tyrant/cmd'
require 'tyrant'

module Cinch; module Plugins; class TyrantSay
  include Cinch::Plugin

  match(/say (.+)/i, method: :say)

  COMMANDS = [
    Cinch::Tyrant::Cmd.new('chat', 'say', '<message>',
      lambda { |m| is_superofficer?(m) },
      'Posts the specified message in faction chat.'
    ),
  ]

  MAX_LENGTH = 160

  FLOOD_INITIAL_TIME = 10
  FLOOD_INCREASE = 2

  def initialize(*args)
    super

    # Flood protection
    @last_request = {}
    @wait_times = Hash.new(FLOOD_INITIAL_TIME)
  end

  def say(m, message)
    return unless is_superofficer?(m)

    user = BOT_CHANNELS[m.channel.name].player
    tyrant = Tyrants.get(user)

    now = Time.now.to_i

    last = @last_request[m.channel.name]
    timer = @wait_times[m.channel.name] || FLOOD_INITIAL_TIME
    @last_request[m.channel.name] = now

    is_master = m.user.master?

    # They are requesting too soon!
    if last && now - last < timer && !is_master
      # Double the time remaining on this channel's timer
      @wait_times[m.channel.name] -= (now - last)
      @wait_times[m.channel.name] *= FLOOD_INCREASE

      # Warn them if it's their first time messing it up
      if timer == FLOOD_INITIAL_TIME
        m.reply('Talking too often. Cool down a bit.', true)
      end

      return
    elsif !is_master
      @wait_times[m.channel.name] = FLOOD_INITIAL_TIME
    end

    if message.length > MAX_LENGTH && !is_master
      diff = MAX_LENGTH - message.length
      m.reply("Your message is too long. Remove #{diff} characters.", true)
      return
    end

    message = CGI.escape(message)
    message = "[IRC/#{m.user.nick}] " + message unless is_master
    args = 'text=' + message

    if shared[:last_faction_chat]
      last_post = shared[:last_faction_chat][tyrant.faction_id]
      args = "last_post=#{last_post}&#{args}" if last_post
    end

    json = tyrant.make_request('postFactionMessage', args)
    if is_master
      json['messages'] = "[#{json['messages'].size} messages]"
      m.reply(json)
    else
      ok = json['result'].nil?
      m.reply("Your message was#{ok ? '' : ' NOT'} posted.", true)
    end
  end
end; end; end
