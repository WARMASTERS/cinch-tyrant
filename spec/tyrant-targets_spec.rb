require_relative 'test-common'

require 'cinch/plugins/tyrant-targets'

describe Cinch::Plugins::TyrantTargets do
  include Cinch::Test

  let(:bot) {
    make_bot(Cinch::Plugins::TyrantTargets) { |c|
      self.loggers.stub('debug') { nil }
    }
  }

  it 'makes a test bot' do
    expect(bot).to be_a Cinch::Bot
  end

  describe '!targets' do
    before :each do
      @conn = FakeConnection.new
      @tyrant = Tyrants.get_fake('testplayer', @conn)
      expect(Tyrants).to receive(:get).with('testplayer').and_return(@tyrant)
      @conn.respond('getFactionInfo', nil, {'rating' => 1000})
    end

    let(:message) { make_message(bot, '!targets', channel: '#test') }

    it 'informs the user when there are no targets' do
      @conn.respond('getFactionRivals', nil, {'rivals' => []})
      replies = get_replies_text(message)
      expect(replies).to be == ['No targets!']
    end

    # TODO: A bit silly that these tests return THE ENEMY twice.

    it 'shows the targets' do
      @conn.respond('getFactionRivals', nil, {'rivals' => [
        {
          'faction_id' => '2000',
          'rating' => '1050',
          'name' => 'THE ENEMY',
          'infamy_gain' => 0,
          'less_rating_time' => 0,
        },
      ]})
      replies = get_replies_text(message)
      expect(replies).to be == ['6: THE ENEMY (1050), THE ENEMY (1050)']
    end

    it 'hides infamy-gaining targets' do
      @conn.respond('getFactionRivals', nil, {'rivals' => [
        {
          'faction_id' => '2000',
          'rating' => '1050',
          'name' => 'THE ENEMY',
          'infamy_gain' => 1,
          'less_rating_time' => 0,
        },
      ]})
      replies = get_replies_text(message)
      expect(replies).to be == ['No targets!']
    end

    it 'stars less-FP targets' do
      @conn.respond('getFactionRivals', nil, {'rivals' => [
        {
          'faction_id' => '2000',
          'rating' => '1050',
          'name' => 'THE ENEMY',
          'infamy_gain' => 0,
          'less_rating_time' => Time.now.to_i,
        },
      ]})
      replies = get_replies_text(message)
      expect(replies).to be == ['3: THE ENEMY* (1050), THE ENEMY* (1050)']
    end
  end
end
