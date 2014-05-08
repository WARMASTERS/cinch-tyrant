require 'cinch'
require 'cinch/tyrant/cmd'
require 'tyrant'
require 'tyrant/cards'
require 'tyrant/conquest'
require 'yaml'

module Cinch; module Plugins; class TyrantConquestCommands
  include Cinch::Plugin

  def self.cqmatch(regex, args)
    args[:prefix] = lambda { |m| /^!c\s+/i }
    match(regex, args.dup)
    args[:prefix] = lambda { |m| m.bot.nick + ': ' }
    match(regex, args.dup)
  end

  match(/cq/i, method: :status)
  match(/slot\s*(\d+)(\s+-s)?/i, method: :slot)

  cqmatch(/slot\s*(\d+)(\s+-s)?/i, method: :slot)
  cqmatch(/stat(?:us)?(?:\s+(\d+))?/i, method: :cstatus)
  cqmatch(/check\s+(\d+)(\s+-s)?/i, method: :check)
  cqmatch(/(?:set|change)\s*(\d+) (.*)/i, method: :cset)
  cqmatch(/setas\s+(\S+)\s+(\d+) (.*)/i, method: :csetas)
  cqmatch(/append\s+(\d+) (.*)/i, method: :update)
  cqmatch(/appendas\s+(\S+)\s+(\d+) (.*)/i, method: :updateas)
  cqmatch(/merge\s+(\d+) (.*)/i, method: :merge)
  cqmatch(/claim\s+(\d+)(?:\s+(.+))?/i, method: :claim)
  cqmatch(/unclaim\s+(\d+)(?:\s+(.+))?/i, method: :unclaim)
  cqmatch(/stuck(?:\s+(\d+)(?:\s+(.+))?)?/i, method: :stuck)
  cqmatch(/unstuck\s+(\d+)(?:\s+(.+))?/i, method: :unstuck)
  cqmatch(/claimed/i, method: :list_claimed)
  cqmatch(/free(\s+-a)?/i, method: :free)
  cqmatch(/known(\s+-(?:a|v))?/i, method: :known)
  cqmatch(/unknown(\s+-a)?/i, method: :unknown)
  cqmatch(/ownerknown(\s+-a)?/i, method: :owner_known)

  cqmatch(/announce\s+(\d+)/i, method: :announce)

  cqmatch(/dump\s+(.+)/i, method: :dump)
  cqmatch(/restore\s+(.+)/i, method: :restore)

  cqmatch(/destroyslot\s+(\d+)/i, method: :destroy_slot)
  cqmatch(/cleardeck\s+(\d+)/i, method: :clear_deck)
  cqmatch(/clearowner\s+(\d+)/i, method: :clear_owner)

  MEMBER_L = lambda { |m| is_member?(m) }

  COMMANDS = [
    Cinch::Tyrant::Cmd.new('invasion', 'c status', '', MEMBER_L,
      'Shows status of the current invasion (shortcut: !cq)'
    ),
    Cinch::Tyrant::Cmd.new('invasion', 'c slot', '<slot>', MEMBER_L,
      'Shows information about the specified slot'
    ),
    Cinch::Tyrant::Cmd.new('invasion', 'c set', '<slot> <contents>', MEMBER_L,
      'Sets the current contents of the specified slot'
    ),
    Cinch::Tyrant::Cmd.new('invasion', 'c append', '<slot> <contents>', MEMBER_L,
      'Adds the contents to the current contents of the specified slot'
    ),
    Cinch::Tyrant::Cmd.new('invasion', 'c merge', '<slot> <contents>', MEMBER_L,
      'Merges the contents with the current contents of the specified slot'
    ),
    Cinch::Tyrant::Cmd.new('invasion', 'c claim', '<slot>', MEMBER_L,
      'Marks you as attacking the specified slot. ' +
      'You will be notified when the slot commander changes.'
    ),
    Cinch::Tyrant::Cmd.new('invasion', 'c unclaim', '<slot>', MEMBER_L,
      'Unmarks you as attacking the specified slot.'
    ),
    Cinch::Tyrant::Cmd.new('invasion', 'c stuck', '<slot>', MEMBER_L,
      'Marks you as stalling a loss on the specified slot. ' +
      'You will be notified when the slot is dead.'
    ),
    Cinch::Tyrant::Cmd.new('invasion', 'c unstuck', '<slot>', MEMBER_L,
      'Unmarks you as attacking the specified slot.'
    ),
    Cinch::Tyrant::Cmd.new('invasion', 'c stuck', '', MEMBER_L,
      'Lists all stuck players and the slots they are stuck on.'
    ),
    Cinch::Tyrant::Cmd.new('invasion', 'c claimed', '', MEMBER_L,
      'Lists all slots with attackers.'
    ),
    Cinch::Tyrant::Cmd.new('invasion', 'c free', '', MEMBER_L,
      'Lists all slots without attackers.'
    ),
    Cinch::Tyrant::Cmd.new('invasion', 'c known', '[-v]', MEMBER_L,
      'Lists all slots whose contents are known. -v to show their contents (SPAM!).'
    ),
    Cinch::Tyrant::Cmd.new('invasion', 'c unknown', '', MEMBER_L,
      'Lists all slots whose contents are unknown.'
    ),
  ]

  # Returns true iff the faction has an invasion.
  # If reply = true, will send a reply to the Message.
  def ensure_invasion(m, faction, reply = true)
    if !faction.invasion_tile && reply
      m.reply('We don\'t seem to have an invasion right now!')
    end
    !faction.invasion_tile.nil?
  end

  # Returns true iff the slot is a valid slot in the faction's invasion.
  # Precondition: faction has a valid invasion (see ensure_invasion)
  # If reply = true, will send a reply to the Message.
  def ensure_slot(m, faction, slot, reply = true)
    if !faction.invasion_info.has_key?(slot) && reply
      m.reply("Slot #{slot} is not a valid slot in the current invasion")
    end
    faction.invasion_info.has_key?(slot)
  end


  def resolve_faction(m)
    raise 'No TyrantConquest plugin' if shared[:conquest_factions].nil?
    shared[:conquest_factions][m.channel.name]
  end

  def cstatus(m, id)
    return unless is_member?(m)

    faction = resolve_faction(m)
    return unless faction.monitor_opts[:status_feedback]
    id ? slot(m, id, false) : status(m)
  end

  def status(m)
    return unless is_member?(m)

    faction = resolve_faction(m)
    return unless ensure_invasion(m, faction)

    last_check_ago = Time.now.to_i - faction.last_check
    if last_check_ago >= MINUTE
      warning = Format(:bold, :red, :underline, 'WARNING!')
      m.reply(warning + ' Last check was over a minute ago! ' +
              'Run "!cnews invasion_monitor on" (ops only)')
    end

    length = faction.invasion_end_time - faction.invasion_start_time
    time_left = faction.invasion_end_time - Time.now.to_i
    alive = faction.slots_alive
    health = 0
    total_health = faction.max_hp * faction.invasion_info.size
    faction.invasion_info.each { |id, s|
      health += s.hp.to_i
    }

    slots_percent = 100.0 * alive / faction.invasion_info.size
    hp_percent = 100.0 * health / total_health
    time_percent = 100.0 * time_left / length

    effect = faction.invasion_effect
    effect_text = effect ? ". #{TyrantTile::EFFECTS[effect]}" : ''

    fmt = "%d/%d (%.2f%%) slots alive. " +
          "%d/%d (%.2f%%) health left. " +
          "%s (%.2f%%) left#{effect_text}."

    data = [
      alive, faction.invasion_info.size, slots_percent,
      health, total_health, hp_percent,
      format_time(time_left), time_percent,
    ]
    m.reply(fmt % data)
  end

  def cset(m, id, deck)
    return unless is_member?(m)

    _cset(m, id, deck, m.user.name)
  end

  def csetas(m, setter, id, deck)
    return unless m.user.master?

    _cset(m, id, deck, setter)
  end

  def update(m, id, deck)
    return unless is_member?(m)

    _cset(m, id, deck, m.user.name, append: true)
  end

  def updateas(m, setter, id, deck)
    return unless m.user.master?

    _cset(m, id, deck, setter, append: true)
  end

  def list_to_hash(list)
    list.split(', ').each_with_object(Hash.new(0)) { |name, hash|
      (name, quantity) = name.split('#')
      quantity = [1, quantity.to_i].max

      hash[name.strip] = quantity
    }
  end

  KNOWN_REGEX = /(.*) (\d+)\/(\d+) known/
  def merge(m, id, new_contents)
    return unless is_member?(m)

    faction = resolve_faction(m)
    return unless ensure_invasion(m, faction)
    return unless ensure_slot(m, faction, id)

    slot = faction.invasion_info[id]
    old_contents = slot.deck

    if match = KNOWN_REGEX.match(old_contents)
      old_contents = match[1]
      old_size = match[3]
    else
      old_size = '?'
    end

    # Remove old commander from list
    old_commander, old_contents = old_contents.split(', ', 2)
    old_hash = list_to_hash(old_contents)
    new_hash = list_to_hash(new_contents)
    merged = old_hash.merge(new_hash) { |k, v1, v2| [v1, v2].max }

    sorted = merged.to_a
    sorted.sort_by! { |a| a[0] }
    num_known = sorted.map { |x| x[1] }.reduce(0, :+)
    new_contents = sorted.map { |name, quantity|
      name + (quantity > 1 ? " ##{quantity}" : '')
    }

    # Add back old commander
    new_contents.unshift(old_commander)
    new_contents = new_contents.join(', ') + " #{num_known}/#{old_size} known"

    _cset(m, id, new_contents, m.user.name)
  end

  def list_stuck(m)
    return unless is_member?(m)

    faction = resolve_faction(m)
    return false unless ensure_invasion(m, faction)

    result = []

    faction.invasion_info.each { |id, s|
      next if s.stuck.empty?

      result << "#{id}: #{s.list_stuck}"
    }
    m.reply(result.empty? ? 'Nobody is stuck!' : result.join("\n"))
  end

  def list_claimed(m)
    return unless is_member?(m)

    faction = resolve_faction(m)
    return false unless ensure_invasion(m, faction)

    result = []

    faction.invasion_info.each { |id, s|
      next if s.attackers.empty?

      result << "#{id}: #{s.list_attackers}"
    }
    m.reply(result.empty? ? 'Nobody has claimed a slot!' : result.join("\n"))
  end

  # Performs the specified operation on the specified set of the specified slot.
  # Returns [slot, target] if operation succeeded, nil if operation failed.
  # If the invoking user is >= warmaster, an arbitrary target can be specified.
  # Otherwise, the target becomes the invoking user.
  def set_check(m, slot_id, target)
    return nil unless is_member?(m)

    faction = resolve_faction(m)
    return nil unless ensure_invasion(m, faction)
    return nil unless ensure_slot(m, faction, slot_id)

    target = m.user.name if target.nil? || !is_warmaster?(m)

    info = faction.invasion_info[slot_id]
    if info[:defeated]
      m.reply("Impossible because slot #{slot_id} is already dead", true)
      return nil
    end

    [info, target]
  end

  def set_add(m, slot_id, target, set_sym, verb)
    result = set_check(m, slot_id, target)
    return nil unless result
    info, target = result

    if info[set_sym].include?(target)
      m.reply("Impossible, #{target} is already #{verb} slot #{slot_id}")
      return nil
    end
    info[set_sym].add(target)
    target
  end

  def set_delete(m, slot_id, target, set_sym, verb)
    result = set_check(m, slot_id, target)
    return nil unless result
    info, target = result

    unless info[set_sym].include?(target)
      m.reply("Impossible, #{target} wasn't #{verb} slot #{slot_id} anyway")
      return nil
    end
    info[set_sym].delete(target)
    target
  end

  def claim(m, id, target)
    result = set_add(m, id, target, :attackers, 'attacking')

    faction = resolve_faction(m)
    if result && faction.monitor_opts[:claim_feedback]
      m.reply("OK, #{result} has claimed slot #{id}")
    end
  end

  def unclaim(m, id, target)
    result = set_delete(m, id, target, :attackers, 'attacking')

    faction = resolve_faction(m)
    if result && faction.monitor_opts[:claim_feedback]
      m.reply("OK, #{result} has released claim on slot #{id}")
    end
  end

  def stuck(m, id, target)
    return list_stuck(m) if id.nil?

    result = set_add(m, id, target, :stuck, 'stuck on')

    faction = resolve_faction(m)
    if result && faction.monitor_opts[:stuck_feedback]
      m.reply("OK, #{result} is stuck on slot #{id}")
    end
  end

  def unstuck(m, id, target)
    result = set_delete(m, id, target, :stuck, 'stuck on')

    faction = resolve_faction(m)
    if result && faction.monitor_opts[:stuck_feedback]
      m.reply("OK, #{result} is no longer stuck on slot #{id}")
    end
  end

  def check(m, id, short)
    return unless is_member?(m)

    faction = resolve_faction(m)
    return unless faction.monitor_opts[:check_feedback]
    slot(m, id, short)
  end

  def slot(m, id, short)
    return unless is_member?(m)

    faction = resolve_faction(m)
    return unless ensure_invasion(m, faction)
    return unless ensure_slot(m, faction, id)

    slot_info = faction.invasion_info[id]
    hp = slot_info[:hp]
    commander_id = slot_info[:commander].to_i
    commander = shared[:cards_by_id][commander_id % 10000]

    info = "#{commander.name}[#{commander_id}] - " +
           "#{commander.health} HP #{commander.skills}"
    m.reply("Slot #{id} #{hp}/#{faction.max_hp} HP #{info}")

    return if short

    if slot_info.deck_set_time
      safename = TyrantConquest::safe_name(slot_info[:deck_set_by])
      set_time = TyrantConquest::safe_time_ago(slot_info[:deck_set_time])
      change_time = TyrantConquest::safe_time_ago(slot_info[:change_time])

      if slot_info.change_time && slot_info.change_time >= slot_info.deck_set_time
        ood = Format(:bold, :red, '(Out of date!)') + ' '
      else
        ood = ''
      end

      m.reply("Owner: #{slot_info.owner || 'unknown'} | " +
              "Deck: #{ood}#{slot_info.deck || 'unknown'} | " +
              "Hash: #{hash_slot(slot_info)}")
      m.reply("Deck set by #{safename}: #{set_time}. " +
              "Deck last changed commanders: #{change_time}")
    else
      change_time = TyrantConquest::safe_time_ago(slot_info[:change_time])
      m.reply("No info on contents of slot #{id}. " +
              "Deck last changed commanders: #{change_time}")
    end

    return if hp.to_i == 0
    return if slot_info.attackers.empty? && slot_info.stuck.empty?
    attackers = "Attacking #{id}: #{slot_info.list_attackers}"
    stuck = "Stuck on #{id}: #{slot_info.list_stuck}"
    m.reply(attackers + ' | ' + stuck)
  end

  def announce(m, id)
    return unless m.user.master?

    faction = resolve_faction(m)
    return unless ensure_invasion(m, faction)
    return unless ensure_slot(m, faction, id)

    slot_info = faction.invasion_info[id]

    message = "[SCOUT] #{id} = #{slot_info.owner}: #{slot_info.deck}"
    message = CGI.escape(message)
    json = faction.tyrant.make_request('postFactionMessage', "text=#{message}")
    ok = json['result'].nil?
    m.reply("OH NOES! " + json) unless ok
  end

  # Lists slots.
  # If passed a block, only lists the slots for which the block returns true.
  def filter_slots(faction)
    list = []

    faction.invasion_info.each { |id, s|
      next if block_given? and not yield s
      list << id
    }

    list
  end

  def unknown(m, all)
    return unless is_member?(m)

    faction = resolve_faction(m)
    return unless ensure_invasion(m, faction)

    unknowns = filter_slots(faction) { |slot|
      (all || slot.hp.to_i > 0) && !slot.known?
    }
    live = all ? faction.invasion_info.size : faction.slots_alive
    m.reply("Unknown slots #{unknowns.size}/#{live}: #{unknowns.join(', ')}")
  end

  def known(m, flags)
    return unless is_member?(m)

    faction = resolve_faction(m)
    return unless ensure_invasion(m, faction)

    verbose = flags && flags.include?('v')
    all = flags && flags.include?('a') && !verbose

    knowns = filter_slots(faction) { |slot|
      (all || slot.hp.to_i > 0) && slot.known?
    }
    live = all ? faction.invasion_info.size : faction.slots_alive
    knowns_str = "#{knowns.size}/#{live}: #{knowns.join(', ')}"

    if verbose
      slots = faction.invasion_info
      decks = knowns.map { |id|
        "#{id}: #{slots[id].deck} | #{hash_slot(slots[id])}"
      }.join("\n")
      m.reply('PMing you known decks ' + knowns_str, true)
      m.user.msg(decks)
    else
      m.reply('Known slots ' + knowns_str)
    end
  end

  def free(m, all)
    return unless is_member?(m)

    faction = resolve_faction(m)
    return unless ensure_invasion(m, faction)

    return unless faction.monitor_opts[:free_feedback]

    free_slots = filter_slots(faction) { |slot|
      (all || slot.hp.to_i > 0) && slot.attackers.empty?
    }
    live = all ? faction.invasion_info.size : faction.slots_alive
    m.reply("Free slots #{free_slots.size}/#{live}: #{free_slots.join(', ')}")
  end

  def owner_known(m, all)
    return unless is_member?(m)

    faction = resolve_faction(m)
    return unless ensure_invasion(m, faction)

    knowns = filter_slots(faction) { |slot|
      (all || slot.hp.to_i > 0) && !slot.owner.nil?
    }
    live = all ? faction.invasion_info.size : faction.slots_alive
    m.reply("Known slots #{knowns.size}/#{live}: #{knowns.join(', ')}")
  end

  private

  # Ugh, somewhat copied from TyrantCard
  ID_REGEX = /.*\[(\d+)\]/
  def resolve_card(name, num_suggestions = 3)
    match = ID_REGEX.match(name)
    if match
      id = match[1].to_i
      c = shared[:cards_by_id][id]
      return [c, []] unless c.nil?
      raise "No card with ID #{id}"
    end

    name = name.strip.downcase

    # If they used a star, replace it with a +
    used_star = false
    if name[-1] == '*'
      used_star = true
      name[-1] = '+'
    end

    card = shared[:cards_by_name][name]
    # If there is an exact match for name, great, return it.
    return [card, []] if card

    raise "No card named '#{name}'"
  end

  def hash_slot(slot)
    return slot[:hash] if slot[:original_format] == :hash

    begin
      contents = slot[:deck]
      match = KNOWN_REGEX.match(contents)
      contents = match[1] if match

      contents.split(',').map { |name|
        (name, quantity) = name.split('#')
        quantity = [1, quantity.to_i].max
        (card, suggestions) = resolve_card(name)
        quantity_hash = quantity == 1 ? '' :
                        ::Tyrant::Cards::hash_of_id(quantity + 4000)
        suggestions.map! { |x| x + ' #' + quantity.to_s } if quantity > 1
        card.hash + quantity_hash
      }.join('')
    rescue => e
      "Error #{e}, try !c hash"
    end
  end

  def _cset(m, id, deck, setter, append: false)
    faction = resolve_faction(m)
    return unless ensure_invasion(m, faction)
    return unless ensure_slot(m, faction, id)

    info = faction.invasion_info[id]
    owner_change = ''

    ai_tile = faction.opponent.nil?

    deck.strip!

    if deck.include?(':')
      owner, deck = deck.split(':', 2)
      deck.strip!
      if owner.strip.empty?
        owner_change = " - #{setter}, why did you specify a blank owner?"
      elsif info.owner == owner
        owner_change = " - deck owner is #{owner}"
      elsif !info.owner || info.owner.empty?
        owner_change = " - owner set to #{owner}"
        info.owner = owner
      else
        owner_change = " - owner changed to #{owner} from #{info.owner}"
        info.owner = owner
      end
    elsif info.owner.nil?
      if ai_tile
        info.owner = 'AI'
        owner_change = ' - deck owner is AI'
      else
        owner_change = " - #{setter}, please set the owner of the deck " +
                       "with \"!c append #{id} OWNERNAME:\"!"
      end
    else
      owner_change = " - deck owner is #{info.owner}"
    end

    was_empty = info.deck.nil?
    changed = false
    original_format = :names
    if !deck.strip.empty?
      # Check if they are setting a hash.
      if !deck.include?(',') && !deck.include?(' ')
        deck2, invalid = ::Tyrant::Cards::unhash(deck)
        if invalid.empty?
          all_valid = deck2.all? { |i, _| shared[:cards_by_id].has_key?(i) }
          if all_valid
            if append
              m.reply('I think you are trying to append a hash, ' +
                      'which I do not support.', true)
              return
            end
            original_format = :hash
            deck2.map! { |cid, count|
              card = shared[:cards_by_id][cid]
              name = card ? card.name : "Unknown card #{cid}"
              count > 1 ? "#{name} ##{count}" : name
            }

            hash = deck
            deck = deck2.join(', ')
          end
        end
      end

      if info.deck && append
        info.deck << ', ' + deck
        changed = true
      elsif info.deck != deck
        info.hash = hash if original_format == :hash
        info.deck = deck
        changed = true
      end
    end
    info.original_format = original_format
    info.deck_set_by = setter
    info.deck_set_time = Time.now.to_i

    if faction.monitor_opts[:cset_feedback]
      if match = KNOWN_REGEX.match(deck)
        known = " (#{match[2]}/#{match[3]} known)"
      else
        known = ''
      end

      verb = was_empty ? 'set' : ((changed ? '' : 'un') + 'changed')
      m.reply("OK, slot #{id} contents " + verb + known + owner_change)
    end
  end

  def dump(m, filename)
    return unless m.user.master?

    faction = resolve_faction(m)
    File.write(filename, faction.invasion_info.to_yaml)
    m.reply('OK, conquest info dumped to that file')
  end

  def restore(m, filename)
    return unless m.user.master?

    faction = resolve_faction(m)
    info = YAML::load_file(filename)
    info.each { |k, v| faction.invasion_info[k] = v }
    m.reply('OK, conquest info loaded from that file')
  end

  def destroy_slot(m, id)
    return unless m.user.master?

    faction = resolve_faction(m)
    return unless ensure_invasion(m, faction)
    return unless ensure_slot(m, faction, id)

    faction.invasion_info.delete(id)
  end

  def clear_deck(m, id)
    return unless m.user.master?

    faction = resolve_faction(m)
    return unless ensure_invasion(m, faction)
    return unless ensure_slot(m, faction, id)

    info = faction.invasion_info[id]
    info.deck = nil
    info.deck_set_by = nil
    info.deck_set_time = nil
  end

  def clear_owner(m, id)
    return unless m.user.master?

    faction = resolve_faction(m)
    return unless ensure_invasion(m, faction)
    return unless ensure_slot(m, faction, id)

    info = faction.invasion_info[id]
    info.owner = nil
  end
end; end; end
