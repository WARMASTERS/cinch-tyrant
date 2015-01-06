require_relative 'test-common'

require 'cinch/plugins/tyrant-targets'

describe Cinch::Plugins::TyrantTargets do
  include Cinch::Test

  let(:bot) {
    make_bot(Cinch::Plugins::TyrantTargets) { |c|
      self.loggers.each { |l| l.level = :fatal }
    }
  }

  it 'makes a test bot' do
    expect(bot).to be_a Cinch::Bot
  end

  before :each do
    @conn = FakeConnection.new
    @tyrant = Tyrants.get_fake('testplayer', @conn)
  end

  describe '!targets' do
    before :each do
      allow(message.user).to receive(:signed_on_at).and_return(0)
      expect(Tyrants).to receive(:get).with('testplayer').and_return(@tyrant)
      @conn.respond('getFactionInfo', '', {'rating' => 1000})
    end

    let(:message) { make_message(bot, '!targets', channel: '#test') }

    it 'informs the user when there are no targets' do
      @conn.respond('getFactionRivals', 'rating%5Flow=0', {'rivals' => []})
      @conn.respond('getFactionRivals', 'rating%5Fhigh=0', {'rivals' => []})
      replies = get_replies_text(message)
      expect(replies).to be == ['No targets!']
    end

    it 'shows the targets' do
      @conn.respond('getFactionRivals', 'rating%5Flow=0', {'rivals' => []})
      @conn.respond('getFactionRivals', 'rating%5Fhigh=0', {'rivals' => [
        {
          'faction_id' => '2000',
          'rating' => '1050',
          'name' => 'THE ENEMY',
          'infamy_gain' => 0,
          'less_rating_time' => 0,
        },
      ]})
      replies = get_replies_text(message)
      expect(replies).to be == ['6: THE ENEMY (1050)']
    end

    it 'hides infamy-gaining targets' do
      @conn.respond('getFactionRivals', 'rating%5Flow=0', {'rivals' => []})
      @conn.respond('getFactionRivals', 'rating%5Fhigh=0', {'rivals' => [
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
      @conn.respond('getFactionRivals', 'rating%5Flow=0', {'rivals' => []})
      @conn.respond('getFactionRivals', 'rating%5Fhigh=0', {'rivals' => [
        {
          'faction_id' => '2000',
          'rating' => '1050',
          'name' => 'THE ENEMY',
          'infamy_gain' => 0,
          'less_rating_time' => Time.now.to_i,
        },
      ]})
      replies = get_replies_text(message)
      expect(replies).to be == ['3: THE ENEMY* (1050)']
    end

    describe 'with name' do
      let(:message) { make_message(bot, '!targets grepme', channel: '#test') }

      it 'filters' do
        @conn.respond('getFactionRivals', 'rating%5Flow=0', {'rivals' => []})
        @conn.respond('getFactionRivals', 'rating%5Fhigh=0', {'rivals' => [
          {
            'faction_id' => '2001',
            'rating' => '1050',
            'name' => 'THE ENEMY',
            'infamy_gain' => 0,
          },
          {
            'faction_id' => '2000',
            'rating' => '1050',
            'name' => 'grepme',
            'infamy_gain' => 0,
          }
        ]})
        replies = get_replies_text(message)
        expect(replies).to be == ['6: grepme (1050)']
      end
    end
  end

  describe 'flood control' do
    def msg
      m = make_message(bot, '!targets', channel: '#test')
      allow(m.user).to receive(:signed_on_at).and_return(0)
      return m
    end

    before :each do
      allow(Tyrants).to receive(:get).with('testplayer').and_return(@tyrant)
      @conn.respond('getFactionInfo', '', {'rating' => 1000})
      @conn.respond('getFactionRivals', 'rating%5Flow=0', {'rivals' => []})
      @conn.respond('getFactionRivals', 'rating%5Fhigh=0', {'rivals' => []})
    end

    it 'warns on second' do
      get_replies(msg)
      replies = get_replies_text(msg)
      expect(replies).to be == ['test: Requesting targets too often. Cool down a bit.']
    end

    it 'remains silent on third and fourth' do
      get_replies(msg)
      get_replies(msg)
      replies = get_replies_text(msg)
      expect(replies).to be == []

      replies = get_replies_text(msg)
      expect(replies).to be == []
    end
  end
end
