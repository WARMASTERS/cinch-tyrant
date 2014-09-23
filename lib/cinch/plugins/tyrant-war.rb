require 'cinch'
require 'cinch/tyrant/cmd'
require 'cinch/tyrant/simple-memory-cache'
require 'tyrant/war'
require 'tyrant/war-report'

module Cinch; module Plugins; class TyrantWar
  include Cinch::Plugin

  match(/w$/i, method: :war)
  match(/w(?:ar)?[^s](\s*-v)?(?:\s*(\d+))?(\s*-v)?(?:\s*(\w+))?/i, method: :war)
  match(/ws(\s*-v)?(?:\s*(\w+))?/i, method: :autowarstats)

  COMMANDS = [
    Cinch::Tyrant::Cmd.new('war', 'war', '',
      lambda { |m| is_member?(m) },
      'Shows score and time remaining in all current wars.'
    ),
    Cinch::Tyrant::Cmd.new('war', 'war', '[-v] <war-id>',
      lambda { |m| is_member?(m) },
      'Shows detailed stats about the specified war. -v for more.'
    ),
    Cinch::Tyrant::Cmd.new('war', 'war', '<war-id> <player>',
      lambda { |m| is_member?(m) },
      'Shows stats about the named player in the specified war.'
    ),
    Cinch::Tyrant::Cmd.new('war', 'ws', '[-v] [player]',
      lambda { |m| is_member?(m) },
      'Acts like !war <war-id> if the faction has only one war.'
    ),
  ]

  def initialize(*args)
    super
    @wars_cache = Cinch::Tyrant::SimpleMemoryCache.new
    @stats_cache = Cinch::Tyrant::SimpleMemoryCache.new
    @info_cache = Cinch::Tyrant::SimpleMemoryCache.new

    @known_ended_wars = Hash.new(0)
    @most_recent_war = {}
  end

  def war(m, v1 = nil, war_id = nil, v2 = nil, player = nil)
    return wars(m) if war_id.nil?
    verbosity = v1.nil? && v2.nil? ? 0 : 1
    return warstats(m, war_id, player, verbosity)
  end

  def wars(m)
    return unless is_member?(m)

    user = BOT_CHANNELS[m.channel.name].player
    tyrant = Tyrants.get(user)

    # TODO: Maybe allow updates to be more frequent if a war is close to ending?
    wars, e = @wars_cache.lookup(tyrant.faction_id, 15, tolerate_exceptions: true) {
      tyrant.current_wars
    }
    m.reply('ERROR refreshing wars! Using last known data.') if e
    m.reply(wars.empty? ? 'No wars!' : tyrant.format_wars(wars))
  end

  # !ws triggers two commands, getCurrentWars and getFactionWarRankings
  # however, this is the same number as the flash client:
  # the flash client does getFactionWar{Info,Rankings}
  def autowarstats(m, verbose, player)
    return unless is_member?(m)

    user = BOT_CHANNELS[m.channel.name].player
    tyrant = Tyrants.get(user)

    wars, e = @wars_cache.lookup(tyrant.faction_id, 15, tolerate_exceptions: true) {
      tyrant.current_wars
    }
    m.reply('ERROR refreshing wars! Using last known data.') if e

    if wars.empty?
      m.reply('No wars!')
    else
      m.reply('More than one war. Use !war <id>') if wars.size > 1
      m.reply(tyrant.format_wars(wars))
      if wars.size == 1
        verbosity = verbose.nil? ? 0 : 1
        id = wars[0]['faction_war_id']
        opponent = wars[0]['name']
        warstats(m, id, player, verbosity,
                 show_score: false, opponent_name: opponent)
      end
    end
  end

  def warstats(m, war_id, player, verbosity,
               show_score: true, opponent_name: nil)
    return unless is_member?(m)

    user = BOT_CHANNELS[m.channel.name].player
    tyrant = Tyrants.get(user)

    if show_score
      json, _ = @info_cache.lookup(war_id, 15, tolerate_exceptions: true) {
        tyrant.make_request('getFactionWarInfo', "faction_war_id=#{war_id}")
      }
      if !json || json['result'] == false
        m.reply('Invalid war ' + war_id.to_s)
        return
      end
      m.reply(tyrant.format_wars([json]))
      opponent_name ||= json['name']
    end

    # We want to cache the wars that have ended.
    # Unfortunately, getFactionWarRankings does not tell us!
    # So, we use old_wars (cached) to build a set of wars that we know
    # have ended already.

    suffix = war_id[-3..-1].to_i
    old_wars = tyrant.old_wars(nil)

    # This war is not known to be ended. Update the known_ended_wars.
    if @known_ended_wars[suffix] < war_id.to_i
      old_wars.each { |w|
        this_id = w['faction_war_id'].to_i
        this_suffix = w['faction_war_id'][-3..-1].to_i
        if @known_ended_wars[this_suffix] < this_id
          @known_ended_wars[this_suffix] = this_id
        end
      }
    end

    # Do not change this to 'else', as we want to re-check.
    # If war has ended, fetch the data and cache to disk.
    # If war has not ended, cache in memory for 15 seconds.
    if @known_ended_wars[suffix] >= war_id.to_i
      json = tyrant.war_rankings(war_id, :both, cache: true)
    else
      json, _ = @stats_cache.lookup(war_id, 15, tolerate_exceptions: true) {
        tyrant.war_rankings(war_id, :both, cache: false)
      }
    end

    if !json || json['result'] == false
      m.reply('Invalid war ' + war_id.to_s)
      return
    end

    other = json.keys.select { |k| k != tyrant.faction_id.to_s }[0]
    us = json[tyrant.faction_id.to_s]
    them = json[other]

    if player
      warstats_player(m, player, tyrant.faction_name, us, opponent_name, them)
    else
      warstats_counts(m, us, them, verbosity)
    end
  end

  def warstats_player(m, player, us_name, us, them_name, them)
    id = player =~ /^[0-9]+$/ ? player : ::Tyrant::id_of_name(player)

    unless id
      m.reply(player + ' not found')
      return
    end
    stats = us.find { |x| x['user_id'].to_i == id.to_i }
    side = stats ? us_name : them_name
    stats ||= them.find { |x| x['user_id'].to_i == id.to_i }
    unless stats
      m.reply(player + ' has not participated in this war')
      return
    end

    dealt = stats['points'].to_i
    taken = stats['points_against'].to_i

    s = '%s (%s): Attack %dW/%dL, Defense %dW/%dL, +%d -%d = %+d'
    dat = [
      player, side,
      stats['wins'].to_i, stats['losses'].to_i,
      stats['defense_wins'].to_i, stats['defense_losses'].to_i,
      dealt, taken, dealt - taken,
    ]
    m.reply(s % dat)
    return
  end

  def warstats_counts(m, us, them, verbosity)
    # Hacktacular since war_report doesn't work with :both, doh!
    # I only want to make one request,
    # so I'll use war_rankings and Playerize manually
    # Used to be map!. This fails with in-memory caching.
    usp = us.map { |p| x = ::Tyrant::Player.new(0, ''); x.add_war(p); x }
    themp = them.map { |p| x = ::Tyrant::Player.new(0, ''); x.add_war(p); x }

    counts = ::Tyrant.war_counts(usp, themp)
    m.reply(::Tyrant::STATS_FMT[verbosity] % counts)
  end

end; end; end
