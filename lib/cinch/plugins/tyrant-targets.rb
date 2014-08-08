require 'cinch'
require 'cinch/tyrant/cmd'
require 'cinch/tyrant/simple-memory-cache'
require 'tyrant/rivals'

module Cinch; module Plugins; class TyrantTargets
  include Cinch::Plugin

  DEFAULT_CONFIG = [nil, nil]

  match(/t(?:argets)?(?:\s+(.+))?$/i)

  COMMANDS = [
    Cinch::Tyrant::Cmd.new('war', 'targets', '',
      lambda { |m| is_warmaster?(m) },
      'Shows factions who are currently open to attack. ' +
      'An asterisk denotes reduced FP gain.'
    ),
  ]

  FLOOD_INITIAL_TIME = 15
  FLOOD_INCREASE = 2

  def initialize(*args)
    super
    @our_fp_cache = Cinch::Tyrant::SimpleMemoryCache.new
    @targets_cache = Cinch::Tyrant::SimpleMemoryCache.new

    # Flood protection
    @last_request = {}
    @wait_times = {}
  end

  def execute(m, name)
    return unless is_warmaster?(m)

    channel = BOT_CHANNELS[m.channel.name]
    user = channel.player
    tyrant = Tyrants.get(user)

    now = Time.now.to_i

    last = @last_request[m.channel.name]
    timer = @wait_times[m.channel.name] || FLOOD_INITIAL_TIME
    @last_request[m.channel.name] = now

    # They are requesting too soon!
    if last && now - last < timer
      # Double the time remaining on this channel's timer
      @wait_times[m.channel.name] -= (now - last)
      @wait_times[m.channel.name] *= FLOOD_INCREASE

      # Warn them if it's their first time messing it up
      if timer == FLOOD_INITIAL_TIME
        m.reply('Requesting targets too often. Cool down a bit.', true)
      end

      return
    else
      @wait_times[m.channel.name] = FLOOD_INITIAL_TIME
    end

    args = (config[:channels] || {})[channel.id] || DEFAULT_CONFIG

    targets, _ = @targets_cache.lookup(tyrant.faction_id, 15) {
      tyrant.raw_rivals(*args)
    }

    info, _ = @our_fp_cache.lookup(tyrant.faction_id, 600) {
      tyrant.make_request('getFactionInfo')
    }
    our_fp = info['rating'] ? info['rating'].to_i : nil

    if name
      targets = targets.select { |target|
        target['name'].downcase.include?(name.downcase)
      }
    else
      targets = targets.select { |target| target['infamy_gain'] == 0 }
    end

    targets = ::Tyrant.rivalize(targets, our_fp)

    m.reply(targets.empty? ? 'No targets!' : ::Tyrant.format_rivals(targets))
  end
end; end; end
