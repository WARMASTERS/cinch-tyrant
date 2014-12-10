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
    Cinch::Tyrant::Cmd.new('war', 'targets', '<name>',
      lambda { |m| is_warmaster?(m) },
      'Shows any targets whose name contains the given name, ' +
      'even those not currently open to attack.'
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

    info = our_info(tyrant)
    our_fp = info['rating'] ? info['rating'].to_i : nil

    if config[:request_pipe] && config[:response_pipe]
      targets = targets_pipe(m, tyrant)
    else
      targets = targets_tyrant(m, channel, tyrant)
    end

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

  def our_info(tyrant)
    info, _ = @our_fp_cache.lookup(tyrant.faction_id, 600) {
      tyrant.make_request('getFactionInfo')
    }
    return info
  end

  def targets_pipe(m, tyrant)
    info = our_info(tyrant)
    our_level = info['level'] && info['level'].to_i

    output = open(config[:request_pipe], 'w+')
    args = { 'request_id' => tyrant.faction_id }
    args['faction_level'] = our_level if our_level
    output.puts(JSON.dump(args))
    output.flush

    input = open(config[:response_pipe], 'r+')
    response = JSON.parse(input.gets)
    response_id = response['response_id']
    if response_id != tyrant.faction_id
      m.reply("Oops, got response for #{response_id}. Try again?", true)
      return []
    end

    # No-cache, we are rate-limited and want very recent wars.
    # This code path is only making this req and maybe an our_info req.
    old_wars = tyrant.old_wars(1, cache: false)
    attack_wars = old_wars.select { |w|
      attack = w['attacker_faction_id'].to_i == tyrant.faction_id
      recent = ::Tyrant::decreased_fp(w['start_time'].to_i)
      attack && recent
    }
    defenders = attack_wars.map { |w| w['defender_faction_id'].to_i }

    response['targets'].reject! { |t| t['id'] == tyrant.faction_id }
    response['targets'].each { |t|
      reduced = defenders.include?(t['id'])
      t['less_rating_time'] = reduced ? Time.now.to_i : 0
    }
    return response['targets']
  end

  def targets_tyrant(m, channel, tyrant)
    args = (config[:channels] || {})[channel.id] || DEFAULT_CONFIG

    targets, _ = @targets_cache.lookup(tyrant.faction_id, 15) {
      tyrant.raw_rivals(*args)
    }

    return targets
  end

end; end; end
