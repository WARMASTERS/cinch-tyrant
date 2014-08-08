require 'cinch'
require 'cinch/tyrant/cmd'
require 'cinch/tyrant/simple-memory-cache'
require 'tyrant/faction'
require 'tyrant/player'
require 'tyrant/sanitize'
require 'tyrant/war-report'

module Cinch; module Plugins; class TyrantPlayer
  include Cinch::Plugin

  RANKS = {
    '0' => 'Applicant',
    '1' => 'Member',
    '2' => 'Officer',
    '3' => 'Leader',
    '4' => 'Warmaster',
  }

  # If a name lookup fails, we try to find the closest name in the faction.
  # This is the threshold (inclusive) for closeness for such a name to be valid.
  NAME_CLOSE_THRESH = 6

  def initialize(*args)
    super
    @tyrant = Tyrants.get(config[:checker])

    @id_cache = Cinch::Tyrant::SimpleMemoryCache.new
    @member_cache = Cinch::Tyrant::SimpleMemoryCache.new
  end

  match(/p(?:layer)?\s+(-v\s+)?(\w+)(?:\s+(\d+))?/i, method: :player)
  match(/d(?:efen[s|c]e)?\s+(\w+)(?:\s*(\d+))?/i, method: :defense)

  COMMANDS = [
    Cinch::Tyrant::Cmd.new('player', 'player', '<name> [days]', true,
      'Looks up information and net performance of the named player ' +
      'for the last n (default 7) days.'
    ),
    Cinch::Tyrant::Cmd.new('player', 'defense', '<name> [days]',
      lambda { |m| is_member?(m) },
      'Looks up defense deck performance of the named player ' +
      'for the last n (default 7) days.'
    ),
  ]

  # Returns [faction id, player name, string of player info]
  # Faction ID is nil if player is not in a faction.
  # If Kong name does not match Tyrant name,
  # Player name is of the form "<Tyrant name> (AKA <Kong name>)"
  def self.player_info(json, kong_name = nil, show_ids: false)
    name = ::Tyrant::sanitize_or_default(json['user_data']['name'], 'null')
    extra = ''
    if kong_name && name.downcase != kong_name.downcase
      extra = " (AKA #{kong_name})"
    end
    name += '[' + json['user_data']['user_id'] + ']' if show_ids
    level = json['user_data']['level']

    if json['faction_data']
      f = json['faction_data']
      fn = ::Tyrant::sanitize_string(f['name'])
      fn += '[' + f['faction_id'] + ']' if show_ids
      rank = RANKS[f['permission_level']]
      # Bleh, string too long...
      wl = "#{f['wins']}/#{f['losses']} W/L"
      lp = "#{f['loyalty']} LP"
      faction = "#{rank} of #{fn}, #{lp}. "
      faction += "#{f['rating']} FP (Level #{f['level']}), #{wl}"

      faction_id = f['faction_id'].to_i
    else
      faction = 'Not in a faction'
      faction_id = nil
    end
    [faction_id, name + extra, "Level #{level}, #{faction}"]
  end

  # Looks up a faction ID in a certain channel.
  # Returns a Tyrant object if we are allowed to look up extra stats.
  # Returns nil if not.
  def self.resolve_faction(faction_id, channel)
    return nil unless BOT_IDS.has_key?(faction_id)
    return nil unless channel

    faction_info = BOT_IDS[faction_id]
    tyrant = nil
    if faction_info.player && faction_info.channels.include?(channel.name)
      tyrant = Tyrants.get(faction_info.player)
    end
    tyrant
  end

  def self.limit_days(days = nil)
    days = days.nil? ? 7 : days.to_i
    days = 1 if days < 1
    days = 28 if days > 28
    days
  end

  # resolve_player(name_or_id, channel) returns:
  # If name_or_id is an ID:
  #   [:id, json] if the ID is a valid Tyrant player
  #   Otherwise, attempts to look up name_or_id as a name (below)
  #
  # If name_or_id is a name:
  #   [:no_kong, nil] if the name is not a Kongregate user
  #   [:no_tyrant, id] if the name is a Kongregate user but not a Tyrant player
  #   [:name, json] if the name is a Kongregate user and a Tyrant player
  #   [:correction, json] if there is a correction for this player
  def resolve_player(name_or_id, channel)
    if name_or_id =~ /^[0-9]+$/
      player_id = name_or_id.to_i
      json, _ = @id_cache.lookup(player_id, 1800, tolerate_exceptions: true) {
        @tyrant.get_player(name_or_id)
      }
      # A nil json['result'] is OK, so just check that it's not false.
      return [:id, json] if json['result'] != false

      # We got here, so the result was false.
      # Now if we try to do the lookup too soon, we get rate-limited.
      sleep(3)
    end

    player_id = ::Tyrant.get_id_of_name(name_or_id)

    correction = false
    if player_id.nil?
      faction = BOT_CHANNELS[channel.name]
      tyrant = faction && faction.player && Tyrants.get(faction.player)
      return [:no_kong, nil] if tyrant.nil?

      # Get a name->ID map of the players in this channel's faction
      members, _ =
        @member_cache.lookup(faction.id, 1800, tolerate_exceptions: true) {
        h = {}
        m = tyrant.get_faction_members
        m.each { |id, v| h[v['name'].downcase] = id.to_i } if m
        h
      }

      # Find best matching name
      best = nil
      best_dist = 1.0 / 0.0
      namedown = name_or_id.downcase
      members.each { |name, id|
        dist = Levenshtein.distance(namedown, name)
        if dist < best_dist
          best_dist = dist
          best = name
        end
      }
      if best_dist <= NAME_CLOSE_THRESH
        player_id = members[best].to_i
        correction = true
      else
        return [:no_kong, nil]
      end
    end

    json, _ = @id_cache.lookup(player_id, 1800, tolerate_exceptions: true) {
      @tyrant.get_player(player_id)
    }
    json && json['user_data'] ?
      [correction ? :correction : :name, json] :
      [:no_tyrant, player_id]
  end


  def defense(m, player_name, days)
    return unless is_member?(m)

    days = self.class.limit_days(days)

    method, json = resolve_player(player_name, m.channel)

    if method == :no_kong
      m.reply("#{player_name} not found")
      return
    elsif method == :no_tyrant
      m.reply("#{player_name} does not play Tyrant")
      return
    end

    player_name = ::Tyrant.get_name_of_id(player_name) if method == :id
    if method == :correction
      kongname = ::Tyrant.get_name_of_id(json['user_data']['user_id'])
      not_kongname = player_name.downcase != kongname.downcase
      not_gamename = player_name.downcase != json['user_data']['name'].downcase
      correctme = not_kongname && not_gamename
      m.reply("#{player_name} not found. Did you mean #{kongname}") if correctme
      player_name = kongname
    end
    faction_id, name, _ = self.class.player_info(json, player_name)
    tyrant = self.class.resolve_faction(faction_id, m.channel)

    prefix = "Defense stats for #{name} for the past #{days} days:"

    if tyrant.nil?
      m.reply(prefix + ' Dunno, wrong faction.')
      return
    end

    wars = tyrant.get_old_wars(days).map { |war| war['faction_war_id'] }

    player = tyrant.war_reports(wars) { |p|
      p['user_id'].to_i == json['user_data']['user_id'].to_i &&
      p['battles_fought'].to_i == 0
    }.values[0]

    if player.nil?
      m.reply(prefix + ' No data.')
      return
    end

    win_p = player.wins.to_f / player.battles.to_f * 100
    data = [
      player.dealt, player.taken, player.net,
      player.wins, player.losses,
      player.wars,
      player.battles == 0 ? 0 : win_p,
      player.points_per_battle,
    ]
    fmt = '+%d -%d = %d net, %d/%d W/L in %d wars, %.2f%% win, %.2f per battle'
    m.reply(prefix)
    m.reply(fmt % data)
  end

  def player(m, verbose, player_name, days)
    # To trigger, must be me and PM, or in an allowed channel
    return if !m.channel && !m.user.master?
    return if m.channel && !is_friend?(m)

    days = self.class.limit_days(days)
    show_ids = verbose && m.user.master?

    method, json = resolve_player(player_name, m.channel)

    if method == :no_kong
      m.reply("#{player_name} not found")
      return
    elsif method == :no_tyrant
      id = show_ids ? "[#{json}]" : ''
      m.reply("#{player_name}#{id} does not play Tyrant")
      return
    end

    player_name = ::Tyrant.get_name_of_id(player_name) if method == :id
    if method == :correction
      kongname = ::Tyrant.get_name_of_id(json['user_data']['user_id'])
      not_kongname = player_name.downcase != kongname.downcase
      not_gamename = player_name.downcase != json['user_data']['name'].downcase
      correctme = not_kongname && not_gamename
      m.reply("#{player_name} not found. Did you mean #{kongname}") if correctme
      player_name = kongname
    end
    faction_id, name, info_string = self.class.player_info(json, player_name,
                                                           show_ids: show_ids)
    tyrant = self.class.resolve_faction(faction_id, m.channel)

    m.reply(name + ': ' + info_string)

    return if tyrant.nil? || !is_member?(m)

    wars = tyrant.get_old_wars(days)
    war_ids = wars.map { |war| war['faction_war_id'] }
    player = tyrant.war_reports(war_ids) { |p|
      p['user_id'].to_i == json['user_data']['user_id'].to_i
    }.values[0]

    return if player.nil?

    totals = [
      player.attack_wins, player.attack_losses,
      player.defense_wins, player.defense_losses,
      player.dealt, player.net,
      player.wars_active,
    ]
    averages = totals.map { |x| x / days }

    fmt = '%d/%d attack, %d/%d defense, %d points, %d net, %d wars'
    m.reply("#{days}-day totals: #{fmt % totals}")
    m.reply("#{days}-day averages: #{fmt % averages}")

    if player.last_war
      war = wars.find { |w| w['faction_war_id'] == player.last_war }
      war_info = tyrant.format_wars([war])
      m.reply("#{player_name} last attacked in this war: #{war_info}")
    else
      m.reply("#{player_name} has not attacked in the last #{days} days.")
    end
  end
end; end; end
