require 'cinch'
require 'cinch/tyrant/cmd'
require 'tyrant/cards'
require 'tyrant/levenshtein'

module Cinch; module Plugins; class TyrantCard
  include Cinch::Plugin

  ID_REGEX = /.*\[(\d+)\]|(^\s*\d+\s*$)/
  BASE64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' +
           'abcdefghijklmnopqrstuvwxyz' +
           '0123456789+/'
  # Max 16 cards (commander, 15 deck), 3 chars per card
  MAX_HASH = 3 * 16

  KNOWN_REGEX = /(.*) \d+\/\d+ known/

  match(/card\s+(-l\s+)?(.+)/i, method: :card)
  match(/h(?:ash)?\s+(.+)/i, method: :hash)
  match(/c hash\s+(\d+)/i, method: :chash)
  match(/unhash\s+(.+)/i, method: :unhash)
  match(/dehash\s+(.+)/i, method: :unhash)
  match(/recard/i, method: :recard)

  COMMANDS = [
    Cinch::Tyrant::Cmd.new('card', 'card', '[-l] <name>', true,
      'Gives you info of the named card. Use -l for fansite link. ' +
      'Look up cards by ID by placing ID in square brackets.'
    ),
    Cinch::Tyrant::Cmd.new('card', 'hash', '<cardlist-or-hash>', true,
      'If given a card list, gives deck hash (base64) of that deck. ' +
      'Bracket notation accepted for card IDs. ' +
      'Card multiples must be specified in #n notation. ' +
      'If given a deck hash, unhashes it.'
    ),
    Cinch::Tyrant::Cmd.new('card', 'unhash', '<hash>', true,
      'Decodes standard deck hash (base64) into card names.'
    ),
    Cinch::Tyrant::Cmd.new('invasion', 'c hash', '<slot>',
      lambda { |m| is_member?(m) },
      'Gives deck hash of the specified slot.'
    ),
  ]

  def initialize(*args)
    super
    _recard
  end

  def resolve_card(name, num_suggestions = 3)
    match = ID_REGEX.match(name)
    if match
      id = match[1] ? match[1].to_i : match[2].to_i
      c = @cards_by_id[id]
      return [c, []] unless c.nil?

      return [@cards_by_id[1], ['Infantry']]
    end

    name = name.strip.downcase

    # If they used a star, replace it with a +
    used_star = false
    if name[-1] == '*'
      used_star = true
      name[-1] = '+'
    end

    card = @cards_by_name[name]
    # If there is an exact match for name, great, return it.
    if !card.nil?
      # However, if they used a star, correct them: it needs to be a +
      suggestions = used_star ? [card.name] : []
      return [card, suggestions]
    end

    # If no match found, try best match
    # If need >1 suggestion, sort the list.
    if num_suggestions > 1
      @keys.sort_by! { |x| Levenshtein.distance(x, name) }
      best = @keys[0]
      suggestions = @keys.take(num_suggestions)
      return [@cards_by_name[best], suggestions]
    end

    # If only need one suggestion, just iterate to find.
    best = nil
    best_dist = 1.0 / 0.0
    @keys.each { |x|
      dist = Levenshtein.distance(x, name)
      if dist < best_dist
        best_dist = dist
        best = x
      end
    }
    [@cards_by_name[best], [best]]
  end

  def hash_card(name)
    (name, quantity) = name.split('#')
    quantity = [1, quantity.to_i].max
    (card, suggestions) = resolve_card(name, 1)
    quantity_hash = quantity == 1 ? '' :
                    ::Tyrant::Cards::hash_of_id(quantity + 4000)
    suggestions.map! { |x| x + ' #' + quantity.to_s } if quantity > 1
    [card.hash + quantity_hash, suggestions]
  end

  def card(m, link, name)
    return unless is_friend?(m)

    (card, suggestions) = resolve_card(name)
    if !suggestions.empty?
      m.reply("#{name} not found! Did you mean: #{suggestions.join(', ')}?")
    end
    m.reply(card)
    return if link.nil?
    m.reply("http://tyrant.40in.net/kg/card.php?id=#{card.id}")
  end

  # Receives the !hash command, tries to decide between unhash or hash
  def hash(m, card_list)
    return unless is_friend?(m)

    if !card_list.include?(',')
      deck, invalid = ::Tyrant::Cards::unhash(card_list.strip, @cards_by_id)
      if invalid.empty?
        all_valid = deck.all? { |id, _| @cards_by_id.has_key?(id % 10000) }
        return unhash(m, card_list) if all_valid
      end
    end
    return _hash(m, card_list)
  end

  def chash(m, slot_id)
    return unless is_member?(m)

    raise 'No TyrantConquest plugin' if shared[:conquest_factions].nil?
    faction = shared[:conquest_factions][m.channel.name.downcase]

    if !faction.invasion_info.has_key?(slot_id)
      m.reply(slot_id + ' is not a valid slot in the current invasion')
      return
    end

    slot = faction.invasion_info[slot_id]

    contents = slot.deck

    if !contents
      m.reply('Nobody scouted slot ' + slot_id + ' so I cannot hash it')
    end

    match = KNOWN_REGEX.match(contents)
    contents = match[1] if match

    # Insert commander if not present
    commander_maybe = contents.split(',').first
    commander_maybe &&= commander_maybe.strip.downcase
    commander_maybe &&= @cards_by_name[commander_maybe]
    if commander_maybe && commander_maybe.type != :commander
      commander_id = slot.commander.to_i % 10000
      commander = @cards_by_id[commander_id].name.gsub(',', '')
      contents = commander + ', ' + contents
    end

    return _hash(m, contents)
  end

  # Does the real hashing
  def _hash(m, card_list)
    changes = []
    cards = card_list.split(',')

    skip_one = false

    cards.map!.with_index { |x, i|
      if skip_one
        skip_one = false
        next
      end

      if i < cards.size - 1 && @comma_names.include?(x.strip.downcase)
        next_name = cards[i + 1].strip
        this_and_next = "#{x}, #{next_name}".downcase
        possible_nexts = @comma_names[x.strip.downcase]
        possible_nexts.each { |pn|
          if this_and_next == pn
            # This + next matches a comma card name.
            # So, merge this and next, then skip the next.
            x = "#{x} #{next_name}"
            skip_one = true
          end
        }
      end

      (pair, suggestion) = hash_card(x)
      if !suggestion.empty?
        text = "[#{x} -> #{suggestion[0]}]"
        changes.push(text)
      end
      pair
    }
    hash = cards.join('')
    m.reply("Corrections: #{changes.join(', ')}") unless changes.empty?
    name = if BOT_MASTERS.include?(m.user.name)
             m.user.name[0] + "\u200b" + m.user.name[1..-1]
           else
             m.user.name
           end
    m.reply("#{name}: #{hash}")
  end

  def unhash(m, hash)
    return unless is_friend?(m)

    hash.strip!

    if hash.size > MAX_HASH
      m.reply('That\'s too long; it can\'t possibly be a hash!', true)
      return
    end

    deck, invalid = ::Tyrant::Cards::unhash(hash, @cards_by_id)

    deck.map! { |id, count|
      card = @cards_by_id[id % 10000]
      name = card ? card.name : "Unknown card #{id}"
      name = "FOIL #{name}" if id >= 10000
      count > 1 ? "#{name} ##{count}" : name
    }

    if !invalid.empty?
      m.reply('Invalid base64 characters: ' + invalid)
    end
    m.reply(hash + ': ' + deck.join(', '))
  end

  def recard(m)
    return unless m.user.master?

    file = config[:xml_file]
    unless file
      m.reply('No XML file defined.')
      return
    end

    by_id, by_name = ::Tyrant::Cards::parse_cards(config[:xml_file])
    shared[:cards_by_id] = by_id
    shared[:cards_by_name] = by_name
    _recard
    m.reply('Recarded.')
  end

  private

  def _recard
    @cards_by_id = shared[:cards_by_id]
    @cards_by_name = shared[:cards_by_name]
    @keys = @cards_by_name.keys
    @comma_names = Hash.new { |h, k| h[k] = [] }
    @cards_by_name.values.select { |c| c.name.include?(?,) }.each { |c|
      parts = c.name.split(', ')
      @comma_names[parts.first.downcase] << c.name.downcase
    }
  end

end; end; end
