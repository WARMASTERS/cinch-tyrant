require_relative 'test-common'

require 'cinch/plugins/tyrant-card'

describe Cinch::Plugins::TyrantCard do
  include Cinch::Test

  let(:bot) {
    make_bot(Cinch::Plugins::TyrantCard, :xml_file => 'testcards.xml') { |c|
      self.loggers.stub('debug') { nil }
    }
  }

  let(:card1) { FakeCard.new(1, 'My First Card Story') }
  let(:card2) { FakeCard.new(2, 'Listen Boy') }

  before :each do
    Cinch::Plugins::TyrantCard.any_instance.stub(:shared).and_return({
      :cards_by_id => {
        1 => card1,
        2 => card2,
      },
      :cards_by_name => {
        'my first card story' => card1,
        'listen boy' => card2,
      },
    })
  end

  it 'makes a test bot' do
    expect(bot).to be_a Cinch::Bot
  end

  describe '!card by name' do
    let(:message) { make_message(bot, '!card listen boy', channel: '#test') }

    it 'displays the card' do
      replies = get_replies_text(message)
      # Kind of "displays the card". cinch convert it to_s for us.
      expect(replies).to be == [card2]
    end
  end

  describe '!card by id without brackets' do
    let(:message) { make_message(bot, '!card 2', channel: '#test') }

    it 'displays the card' do
      replies = get_replies_text(message)
      # Kind of "displays the card". cinch convert it to_s for us.
      expect(replies).to be == [card2]
    end
  end

  describe '!card by id' do
    let(:message) { make_message(bot, '!card [2]', channel: '#test') }

    it 'displays the card' do
      replies = get_replies_text(message)
      # Kind of "displays the card". cinch convert it to_s for us.
      expect(replies).to be == [card2]
    end
  end

  # TODO: card with spell corrections

  describe '!hash names' do
    let(:message) { make_message(bot, '!hash listen boy', channel: '#test') }

    it 'displays deck hash' do
      replies = get_replies_text(message)
      expect(replies).to be == ['test: AC']
    end
  end

  # TODO: hash with spell corrections

  shared_examples 'a command that converts hash to names' do
    it 'displays card names' do
      replies = get_replies_text(message)
      expect(replies).to be == ['ACAB: Listen Boy, My First Card Story']
    end
  end

  # TODO: unhashing an invalid hash

  describe '!hash hash' do
    let(:message) { make_message(bot, '!hash ACAB', channel: '#test') }

    it_behaves_like 'a command that converts hash to names'
  end

  describe '!unhash' do
    let(:message) { make_message(bot, '!unhash ACAB', channel: '#test') }

    it_behaves_like 'a command that converts hash to names'
  end

  describe '!dehash' do
    let(:message) { make_message(bot, '!dehash ACAB', channel: '#test') }

    it_behaves_like 'a command that converts hash to names'
  end

  describe '!recard' do
    let(:message) { make_message(bot, '!recard', channel: '#test') }
    let(:newcard1) { FakeCard.new(1, 'Star War The Fourth Gathers') }
    let(:newcard2) { FakeCard.new(2, 'A New Card') }

    before :each do
      message.user.stub(:master?).and_return(true)
      expect(Tyrant::Cards).to receive(:parse_cards).and_return([
        { 1 => newcard1, 2 => newcard2, },
        { 'star war the fourth gathers' => newcard1, 'a new card' => newcard2 },
      ])
      @replies = get_replies_text(message)
    end

    it 'reads card file' do
      expect(@replies).to be == ['Recarded.']
    end


    it 'updates the cards-by-name hash' do
      replies = get_replies_text(make_message(bot, '!card a new card', channel: '#test'))
      # Kind of "displays the card". cinch convert it to_s for us.
      expect(replies).to be == [newcard2]
    end

    it 'updates the cards-by-ID hash' do
      replies = get_replies_text(make_message(bot, '!card [1]', channel: '#test'))
      # Kind of "displays the card". cinch convert it to_s for us.
      expect(replies).to be == [newcard1]
    end
  end
end
