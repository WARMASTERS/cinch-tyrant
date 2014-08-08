require 'cinch'
require 'cinch/tyrant/cmd'
require 'tyrant'
require 'tyrant/conquest'
require 'tyrant/sanitize'
require 'tyrant/time'

module Cinch; module Plugins; class TyrantConquest
  include Cinch::Plugin

  match(/(?:conquest|tiles)( -v)?(?: (.+))?/i, method: :conquest)

  COMMANDS = [
    Cinch::Tyrant::Cmd.new('conquest', 'tiles', '[faction]', true,
      'Shows information on tiles the specified faction (default us) ' +
      'own or are attacking'
    ),
  ]

  # Returns our uncontested, our attacked, our invasions
  def self.classify_tiles(tiles, faction_id)
    our_tiles = tiles.select { |tile|
      tile['faction_id'].to_i == faction_id
    }
    our_uncontested_tiles, our_attacked_tiles = our_tiles.partition { |tile|
      tile['attacking_faction_id'].nil?
    }
    invading_tiles = tiles.select { |tile|
      tile['attacking_faction_id'].to_i == faction_id
    }

    [our_uncontested_tiles, our_attacked_tiles, invading_tiles]
  end

  def self.id_of_name(tiles, name)
    ids = {}
    nsd = name.strip.downcase

    tiles.each { |tile|
      fn = tile['faction_name']
      if fn && fn.strip.downcase.start_with?(nsd)
        ids[tile['faction_id'].to_i] = fn
      end

      afn = tile['attacking_faction_name']
      if afn && afn.strip.downcase.start_with?(nsd)
        ids[tile['attacking_faction_id'].to_i] = afn
      end
    }

    ids
  end

  def self.tile_name(tile)
    coords = ::Tyrant.format_coord(tile['x'].to_i, tile['y'].to_i)
    "%4d (#{coords})" % [tile['system_id'].to_i]
  end

  def self.safe_time_ago(time)
    return 'Never' if time == nil
    ::Tyrant::Time::format_time(Time.now.to_i - time) + ' ago'
  end

  def self.safe_name(name)
    return 'nobody' if name == nil
    name[0] + "\u200b" + name[1..-1]
  end

  def map_hash
    h = shared[:conquest_map_hash]
    raise 'No poll plugin' if !h
    h
  end

  def conquest(m, verbose, faction)
    return unless is_friend?(m)

    if faction
      ids = TyrantConquest::id_of_name(map_hash.values, faction)
      if ids.size == 1
        id = ids.keys[0]
      elsif ids.size == 0 && faction.to_i.to_s == faction
        # Couldn't find it, but faction is a number. Try to lookup by ID
        id = faction.to_i
      elsif ids.size == 0
        # Couldn't find it and faction is not a number. Just fail.
        m.reply("Faction #{faction} is not on the map")
        reply
      else
        m.reply('Multiple factions with this name! ' + ids.to_a.to_s)
        return
      end
    else
      id = BOT_CHANNELS[m.channel.name].id
    end
    l = TyrantConquest::classify_tiles(map_hash.values, id)

    if id == 0
      tiles = map_hash.values

      neutral = tiles.select { |tile| tile['faction_id'].nil?  }
      freq = Hash.new(0)
      cr = 0
      neutral.each { |x|
        rating = x['rating'].to_i
        freq[rating] += 1
        cr += rating
      }
      counts = freq.to_a.map { |k, v| "#{k} CR: #{v}" }.join(', ')
      cr = neutral.map { |x| x['rating'].to_i }.reduce(0, :+)
      size = neutral.size
      m.reply("There are #{size} neutral tiles totaling #{cr} CR. " + counts)
      return if verbose.nil?
      neutral_str = neutral.map { |tile|
        TyrantConquest::tile_name(tile)
      }.join('; ')
      m.reply(neutral_str)
      return
    end

    l = TyrantConquest::classify_tiles(map_hash.values, id)
    (our_uncontested_tiles, our_attacked_tiles, invading_tiles) = l

    our_uncontested_str = our_uncontested_tiles.map { |tile|
      TyrantConquest::tile_name(tile)
    }.join('; ')
    our_attacked_str = our_attacked_tiles.map { |tile|
      ::Tyrant.format_tile_short(tile)
    }.join("\n")
    invading_str = invading_tiles.map { |tile|
      ::Tyrant.format_tile_short(tile)
    }.join("\n")

    u_cr = our_uncontested_tiles.map { |t| t['rating'].to_i }.reduce(0, :+)

    m.reply(invading_str) unless invading_str.empty?
    m.reply(our_attacked_str) unless our_attacked_str.empty?
    if !our_uncontested_str.empty?
      name = ::Tyrant::sanitize_or_default(
        our_uncontested_tiles[0]['faction_name'], '(nil)'
      )
      s = verbose.nil? ? 'Use -v to list' : our_uncontested_str
      n_uc = our_uncontested_tiles.size
      m.reply("#{name}'s uncontested tiles (#{n_uc}, #{u_cr} CR): #{s}")
    elsif invading_str.empty? && our_attacked_str.empty?
      m.reply("Faction #{id} is not on the map")
    end
  end
end; end; end
