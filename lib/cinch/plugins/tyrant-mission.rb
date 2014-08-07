require 'cinch'
require 'cinch/tyrant/cmd'
require 'tyrant'

module Cinch; module Plugins; class TyrantMission
  include Cinch::Plugin

  match(/m(?:ission)? (.+)/i, method: :mission)

  COMMANDS = [
    Cinch::Tyrant::Cmd.new('card', 'mission', '<cards>', true,
      'Finds all missions that contain the listed cards.'
    ),
  ]

  Mission = Struct.new(:name, :commander, :cards)

  def initialize(*args)
    super
    @missions = self.class.parse_missions(config[:xml_file])
  end

  def self.parse_missions(filename)
    missions = []
    doc = Nokogiri::XML(IO.read(filename))
    doc.xpath('//mission').each { |xml|
      name = xml.get_one('name')
      commander = xml.get_one('commander').to_i
      deck = xml.xpath('deck')
      raise 'too many decks' if deck.count > 1
      deck = deck.first

      cards = Hash.new(0)

      deck.xpath('card').each { |c| cards[c.content.to_i] += 1 }
      missions << Mission.new(name, commander, cards)
    }
    missions
  end

  # Ugh, somewhat copied from TyrantCard
  ID_REGEX = /.*\[(\d+)\]|(^\s*\d+\s*$)/
  def resolve_card(name, num_suggestions = 3)
    match = ID_REGEX.match(name)
    if match
      id = match[1] ? match[1].to_i : match[2].to_i
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

  def mission(m, cards)
    return unless is_friend?(m)

    candidates = nil
    errors = []
    cards.split(',').each { |c|
      begin
        card, _ = resolve_card(c)
        if card.type == :commander
          if candidates
            candidates.select! { |ms| ms.commander == card.id }
          else
            candidates = @missions.select { |ms| ms.commander == card.id }
          end
        else
          if candidates
            candidates.select! { |ms| ms.cards.include?(card.id) }
          else
            candidates = @missions.select { |ms| ms.cards.include?(card.id) }
          end
        end
      rescue => e
        errors << e.message
      end
    }
    candidates ||= @missions

    m.reply("Errors: #{errors.join(', ')}") unless errors.empty?
    if candidates.size <= (config[:max_matches] || 1)
      m.reply("#{candidates.size} matches: #{candidates.map { |c| c.name }.join(', ')}")
    else
      m.reply("#{candidates.size} matches: Maybe you should narrow down a bit more.")
    end
  end
end; end; end
