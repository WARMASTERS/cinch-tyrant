require 'cinch'
require 'cinch/tyrant/cmd'
require 'cinch/tyrant/simple-memory-cache'
require 'date'
require 'tyrant/player'
require 'tyrant/raid'

module Cinch; module Plugins; class TyrantRaids
  include Cinch::Plugin

  match(/r(?:aid)? (-[ku]+ )?\s*(\w+)/i, method: :raid_auto)
  match(/fraids/i, method: :fraids)
  match(/raids (.*)/i, method: :raids)

  COMMANDS = [
    Cinch::Tyrant::Cmd.new('raids', 'raid', '[-u] <name|id>', true,
      'Shows info about the raid with the given ID ' +
      'or started by the named player. ' +
      '-u forces parsing as a username, not an ID.'
    ),
    Cinch::Tyrant::Cmd.new('raids', 'fraids', '',
      lambda { |m| is_member?(m) },
      'Shows raids posted to faction news. ' +
      'Use !raid <id> to look up the raids displayed by this command.'
    ),
    Cinch::Tyrant::Cmd.new('raids', 'raids', '<raidtype>', true,
      'Displays public raids of the specified type. ' +
      'Raids may be specified by numeric ID, full name, initials, or prefix.'
    ),
  ]

  def initialize(*args)
    super
    @faction_cache = Cinch::Tyrant::SimpleMemoryCache.new
    @public_cache = Cinch::Tyrant::SimpleMemoryCache.new
    @raid_cache = Cinch::Tyrant::SimpleMemoryCache.new

    @raid_names = {}
    @initials = {}
    @raids = ::Tyrant::parse_raids(config[:xml])
    @raids.each { |raid|
      @raid_names[raid.name.downcase] = raid.id
      words = raid.name.split
      next if words.size == 1
      abbrev = words.map { |x| x[0] }.join.downcase
      @initials[abbrev] = raid.id
    }
  end

  def raid_auto(m, flags, name_or_id)
    # If username is all numbers, parse as ID unless -u flag given.
    if name_or_id =~ /^[0-9]+$/ && (!flags || !flags.include?('u'))
      raid_id(m, flags, name_or_id)
    else
      raid_user(m, flags, name_or_id)
    end
  end

  def raid_id(m, k, raid_id)
    return unless m.channel ? is_friend?(m) : m.user.master?

    tyrant = Tyrants.get(config[:checker])

    json, _ = @raid_cache.lookup(raid_id, 60, tolerate_exceptions: true) {
      tyrant.raid_info(raid_id.to_i)
    }

    show_key = k && k.include?('k') && m.user.master?

    if !json['raid_info'] || json['raid_info'].empty?
      m.reply('No such raid ' + raid_id.to_s)
      return
    end

    info = ::Tyrant.format_raid(@raids, json['raid_info'])
    if show_key
      key = ::Tyrant.raid_key(json)
      info << " | Key: #{raid_id}#{key}"
    end
    m.reply(info)
  end

  def raid_user(m, k, user)
    return unless m.channel ? is_friend?(m) : m.user.master?

    id = ::Tyrant.id_of_name(user)
    if id.nil?
      m.reply "#{user} not found"
      return
    end

    raid_id(m, k, id)
  end

  def raids(m, req)
    return unless is_friend?(m)

    req.downcase!
    if req == req.to_i.to_s
      raid_id = req.to_i
    elsif req.size > 1 && req.size < 5 && @initials.has_key?(req)
      raid_id = @initials[req]
    elsif key = @raid_names.keys.find { |x| x.start_with?(req) }
      raid_id = @raid_names[key]
    else
      best_dist = 1.0 / 0.0
      @raid_names.merge(@initials).each { |x, id|
        dist = Levenshtein.distance(x, req)
        if dist < best_dist
          best_dist = dist
          raid_id = id
        end
      }
    end

    raid = @raids[raid_id]

    if !raid
      m.reply('Sorry, ' + req + ' is not a valid raid.')
      return
    end

    tyrant = Tyrants.get(config[:checker])
    json, _ = @public_cache.lookup(raid_id, 60, tolerate_exceptions: true) {
      tyrant.make_request('getPublicRaids', 'raid_id=' + raid_id.to_s)
    }

    if json['public_raids'].empty?
      m.reply('Sorry, there are no public ' + raid.name)
      return
    end

    # TODO: Stop the spam if there are too many raids.

    json['public_raids'].each { |x|
      # Convert raid to same format as getRaidInfo
      x['end_time'] = x['start_time'].to_i + raid.time
      x['raid_members'] = Array.new(x['num_members'].to_i)
      m.reply(x['user_raid_id'] + ' ' + ::Tyrant.format_raid(@raids, x))
    }
  end

  def fraids(m)
    return unless is_member?(m)

    user = BOT_CHANNELS[m.channel.name].player
    tyrant = Tyrants.get(user)

    json, _ = @faction_cache.lookup(tyrant.faction_id, 60, tolerate_exceptions: true) {
      tyrant.make_request('getFactionNews')
    }
    raids = json['news'].select { |item| item['type'].to_i == 30 }
    now = Time.now.to_i

    # TODO: Display each raid ID once only, along with its posters.

    # TODO: Stop the spam if there are too many faction raids.

    raids.select! { |raid|
      time_ago = now - raid['time'].to_i
      raid = @raids[raid['value'].to_i]
      raid && raid.time >= time_ago
    }

    raids.each { |raid|
      raid_name = @raids[raid['value'].to_i].name
      raid_id = raid['target_faction_id']
      poster = ::Tyrant::name_of_id(raid['user_id'])
      m.reply("#{raid_name} #{raid_id} posted by #{poster}")
    }
    m.reply('No raids!') if raids.empty?
  end
end; end; end
