require 'cinch'
require 'cinch/tyrant/cmd'
require 'tyrant'
require 'tyrant/conquest'

require 'cinch/tyrant/simple-memory-cache'

module Cinch; module Plugins; class TyrantTile
  include Cinch::Plugin

  EFFECTS = [
    'zero? wat?',
    'Time Surge',
    'Copycat',
    'Quicksilver',
    'Decay',
    'High Skies',
    'Impenetrable',
    'Invigorate',
    'Clone Project',
    'Friendly Fire',
    'Genesis',
    'Artillery Strike',
    'Photon Shield',
    'Decrepit',
    'Forcefield',
    'Chilling Touch',
    'Clone Experiment',
    'Toxic',
  ]

  TILE_REGEX =
    /tile\s+(-v\s+)?(0|([2-9]|1[0-6]?)\s*(e|w))\s*,?\s*(0|([2-9]|1[0-6]?)\s*(n|s))/i

  match(/tile\s+(-v\s+)?([1-9]\d*)$/i, method: :tile)
  match TILE_REGEX, method: :tile_coord

  COMMANDS = [
    Cinch::Tyrant::Cmd.new('conquest', 'tile', '<tile>', true,
      'Shows info about the specified tile. ' +
      'Tiles may be specified by coordinates or ID (from !conquest).'
    ),
  ]

  def initialize(*args)
    super

    tyrant = Tyrants.get(config[:checker])
    tiles = tyrant.make_request('getConquestMap')['conquest_map']['map']
    @grid = Array.new(33) { |_| Array.new(33) }
    tiles.each { |t|
      id = t['system_id'].to_i
      @grid[t['x'].to_i][t['y'].to_i] = id
    }

    @cache = Cinch::Tyrant::SimpleMemoryCache.new
  end

  def tile_coord(m, verbose, z1, x, ew, z2, y, ns)
    if z1 == '0'
      x = 0
    else
      x = x.to_i
      x *= -1 if ew.downcase == 'w'
    end
    if z2 == '0'
      y = 0
    else
      y = y.to_i
      y *= -1 if ns.downcase == 'n'
    end

    id = @grid[x][y]
    tile(m, verbose, id)
  end

  def tile(m, verbose, tile_id)
    return unless is_friend?(m)

    player = BOT_CHANNELS[m.channel.name].player
    user = player || config[:checker]
    tyrant = Tyrants.get(user)
    # If this channel has a player, faction_id is their faction id.
    # Otherwise, use the default lookup player, and faction_id is nil.
    faction_id = player && tyrant.faction_id

    # This is dumb, but if I use tile_coord, I need to convert to_s
    # Maybe it should be the other way around? Convert the hash keys to_i?
    tile = shared[:conquest_map_hash][tile_id.to_s]

    if !tile
      m.reply("Tile #{tile_id} does not exist")
      return
    end

    owned = tile['faction_id'].to_i == faction_id
    defending = tile['attacking_faction_id'].to_i == faction_id

    show_ids = verbose && m.user.master?

    text = ::Tyrant.format_tile(tile, show_ids: show_ids)
    effect = tile['effect'] && tile['effect'].to_i
    text += ", #{EFFECTS[effect]}" if effect
    m.reply(text)

    # If not owned or defending, I can't see the slots, so don't bother.
    return if !owned && !defending

    json, _ = @cache.lookup(tile_id, 15) {
      tyrant.make_request('getConquestTileInfo', "system_id=#{tile_id}")
    }
    max_health = json['system']['max_health'].to_i
    slots = json['system']['slots']

    if !slots
      m.reply('Error retrieving slot data, even though we should be able to')
      return
    end

    slots = slots.values

    defeated = slots.count { |slot| slot['defeated'].to_i != 0 }
    alive = slots.size - defeated
    slots_percent = 100.0 * alive / slots.size
    health = slots.map { |slot| slot['health'].to_i }.reduce(0, :+)
    total_health = max_health * slots.size
    hp_percent = 100.0 * health / total_health

    fmt = "%d/%d (%.2f%%) slots alive. " +
          "%d/%d (%.2f%%) health left."
    data = [
      alive, slots.size, slots_percent,
      health, total_health, hp_percent,
    ]

    if json['system']['attacking_faction_id']
      invasion_start_time = json['system']['attack_start_time'].to_i
      invasion_end_time = json['system']['attack_end_time'].to_i
      length = invasion_end_time - invasion_start_time
      time_left = invasion_end_time - Time.now.to_i
      time_percent = 100.0 * time_left / length
      fmt << ' %s (%.2f%%) left.'

      data << format_time(time_left)
      data << time_percent
    end

    m.reply(fmt % data)
  end
end; end; end
