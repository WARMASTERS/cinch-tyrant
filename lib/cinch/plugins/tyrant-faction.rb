require 'cinch'
require 'cinch/tyrant/cmd'
require 'cinch/tyrant/simple-memory-cache'
require 'tyrant/factions'
require 'tyrant/levenshtein'
require 'tyrant/time'
require 'yaml'

module Cinch; module Plugins; class TyrantFaction
  include Cinch::Plugin

  def initialize(*args)
    super
    file = config[:yaml_file] || ''
    @factions = File.exist?(file) ? YAML.load_file(file) : {}
    @keys = @factions.keys
    @cache = Cinch::Tyrant::SimpleMemoryCache.new
    @failures = {}
  end

  match(/f(?:action)?(\s+-[a-z]+)?(?:\s+(.+))?$/i, method: :faction)
  match(/f(?:action)?id\s+(-[a-z]+\s+)?(\d+)/i, method: :faction_id)
  match(/link(?: (.*))?/i, method: :link)
  match(/update rankings/i, method: :update_rankings)
  match(/update conquest/i, method: :update_conquest)

  COMMANDS = [
    Cinch::Tyrant::Cmd.new('factions', 'faction', '[flags] [name]', true,
      'Looks up information of the named faction ' +
      '(default this channel\'s faction). ' +
      'Flags: -c: Conquest attacks, -f: Founder, -m: Message.'
    ),
    Cinch::Tyrant::Cmd.new('factions', 'link', '',
      lambda { |m| is_member?(m) },
      'Shows apply link of this channel\'s faction.'
    ),
    Cinch::Tyrant::Cmd.new('factions', 'link', '<faction>',
      lambda { |m| is_warmaster?(m) },
      'Shows apply link of the named faction.'
    ),
  ]

  def update_rankings(m)
    return if !m.user.master?

    tyrant = Tyrants.get(config[:checker])
    @factions = tyrant.update_rankings
    @keys = @factions.keys
  end

  def update_conquest(m)
    return if !m.user.master?

    tyrant = Tyrants.get(config[:checker])
    @factions = tyrant.update_conquest
    @keys = @factions.keys
  end

  def link(m, faction_name)
    # To trigger, must be me and PM, or in an allowed channel
    return if !m.channel && !m.user.master?
    return if m.channel && !is_member?(m)

    if faction_name
      if !m.channel || is_warmaster?(m)
        faction_id = @factions.get_first(faction_name)
        if !faction_id
          m.reply("#{faction_name} not found")
          return
        end
      else
        return
      end
    else
      faction_id = BOT_CHANNELS[m.channel.name].id
    end

    m.reply("http://www.kongregate.com/games/synapticon/tyrant?kv_apply=#{faction_id}")
  end

  def self.conquest_attacks(json)
    attacks = json['conquest_attacks'].to_i
    return '6/6 attacks' if attacks == 6
    # Far I can tell conquest_attack_recharge is actually time of last attack
    last_attack = json['conquest_attack_recharge'].to_i
    time_since_last = Time.now.to_i - last_attack
    next_charge = -time_since_last % (4 * ::Tyrant::Time::HOUR)
    "#{attacks}/6 attacks - next in #{::Tyrant::Time::format_time(next_charge)}"
  end

  def faction(m, verbose, faction_name)
    # To trigger, must be me and PM, or in an allowed channel
    return if !m.channel && !m.user.master?
    return if m.channel && !is_friend?(m)

    wait_times = config[:wait_time] || {}
    wait_time = wait_times[m.channel.name.downcase] || 900

    if m.user.signed_on_at.to_i + wait_time > Time.now.to_i
      m.reply('STAY A WHILE AND LISTEN! ' +
              'It is very rude to ask for info right after signing on.', true)
      return
    end

    last_fail = m.channel && @failures[m.channel.name]
    if faction_name && last_fail == faction_name && !m.user.master?
      m.reply('No, I really don\'t know about that faction, ' +
              'so please stop trying. It won\'t help.', true)
      return
    end

    # Remember, this quits your faction, so only run with dummy accounts
    tyrant = Tyrants.get(config[:checker])

    # If name provided, use it.
    # If not, use the faction associated with this channel, if any.
    if faction_name
      faction_id = @factions.get_first(faction_name)
    elsif m.channel && BOT_CHANNELS[m.channel.name]
      faction_id = BOT_CHANNELS[m.channel.name].id
    else
      return
    end

    if !faction_id
      @failures[m.channel.name] = faction_name if m.channel
      @keys.sort_by! { |x| Levenshtein.distance(x, faction_name.downcase) }
      suggestions = @keys.take(3).join(', ')
      best = @keys[0]
      m.reply("#{faction_name} not found! Did you mean: #{suggestions}?")
      faction_id = @factions.get_first(best)
      faction_name = best
    end

    json, _ = @cache.lookup(faction_id.to_i, 600, tolerate_exceptions: true) {
      tyrant.faction_data(faction_id)
    }
    if !json['result']
      m.reply('Failed to get info on "' + (faction_name || 'own faction') +
              '". This probably means they disbanded.')
    else
      send_faction_info(m, verbose, json)
    end
  end

  def faction_id(m, verbose, faction_id)
    # To trigger, must be me
    return if !m.user.master?

    # Remember, this quits your faction, so only run with dummy accounts
    tyrant = Tyrants.get(config[:checker])

    json, _ = @cache.lookup(faction_id.to_i, 600, tolerate_exceptions: true) {
      tyrant.faction_data(faction_id)
    }
    if !json['result']
      m.reply('Failed to look up "' + faction_id +
              '". This probably means they disbanded.')
    else
      send_faction_info(m, verbose, json)
    end
  end

  def send_faction_info(m, verbose, json)
    m.reply(::Tyrant.format_faction(json))
    expected_id = m.channel && BOT_CHANNELS[m.channel].id
    if verbose && (m.user.master? || json['faction_id'].to_i == expected_id)
      if verbose.include?('m')
        m.reply('Message: ' + (json['message'] || 'nil'))
      end
      if verbose.include?('f')
        id = json['creator_id']
        name = ::Tyrant::name_of_id(json['creator_id'])
        m.reply("Founder #{name}[#{id}]")
      end
      if verbose.include?('c')
        m.reply(self.class.conquest_attacks(json))
      end
    end
  end

end; end; end
