require_relative 'test-common'

require 'cinch/plugins/tyrant-card'

describe Cinch::Plugins::TyrantCard do
  include Cinch::Test

  let(:bot) {
    make_bot(Cinch::Plugins::TyrantCard) { |c|
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
end
