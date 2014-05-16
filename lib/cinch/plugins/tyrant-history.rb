require 'cinch'
require 'cinch/tyrant/cmd'
require 'date'
require 'tyrant/player'
require 'tyrant/raid'
require 'tyrant/war'

module Cinch; module Plugins; class TyrantHistory
  include Cinch::Plugin

  match(/(?:last|history)(?:\s*(-c))?(?:\s*(\d+))?(?:\s*(.+))?/i, method: :history)

  COMMANDS = [
    Cinch::Tyrant::Cmd.new('war', 'last', '[n] [name]',
      lambda { |m| is_member?(m) },
      'Shows the last n (default 1) wars against the specified opponent (default all opponents)'
    ),
  ]

  FLOOD_INITIAL_TIME = 3
  FLOOD_INCREASE = 2

  def initialize(*args)
    super

    # Flood protection
    @last_request = {}
    @wait_times = {}
  end

  def history(m, skip_cache, count, name)
    return unless is_member?(m)

    # If I (and only I) provide the -c flag, we don't cache.
    use_cache = skip_cache.nil? || !m.user.master?

    count = count.nil? ? 1 : count.to_i
    count = 1 if count < 1
    count = 5 if count > 5

    user = BOT_CHANNELS[m.channel.name].player
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
        m.reply('Requesting history too often. Cool down a bit.', true)
      end

      return
    else
      @wait_times[m.channel.name] = FLOOD_INITIAL_TIME
    end

    # Last 28 days, since this is time for which history is reliable.
    orig_wars = tyrant.get_old_wars(28, use_cache)
    if name.nil?
      wars = orig_wars.take(count)
    else
      name = name.strip.downcase
      wars = orig_wars.select { |war|
        war['name'].strip.downcase == name
      }.take(count)
    end

    # Odd behavior on a new faction that has no wars,
    # but we'll overlook that.
    if wars.empty?
      best = nil
      best_dist = 1.0 / 0.0
      orig_wars.each { |war|
        dist = Levenshtein.distance(name, war['name'].strip.downcase)
        if dist < best_dist
          best_dist = dist
          best = war['name']
        end
      }
      m.reply("No wars against \"#{name}\" in the last 28 days. " +
              "Did you mean #{best}?")
      wars = orig_wars.select { |war|
        war['name'].strip.downcase == best.strip.downcase
      }.take(count)
    end

    m.reply(tyrant.format_wars(wars))
  end
end; end; end
