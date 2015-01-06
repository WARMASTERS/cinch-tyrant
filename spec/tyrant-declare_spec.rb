require_relative 'test-common'

require 'cinch/plugins/tyrant-declare'

describe Cinch::Plugins::TyrantDeclare do
  include Cinch::Test

  let(:bot) {
    make_bot(Cinch::Plugins::TyrantDeclare) { |c|
      self.loggers.each { |l| l.level = :fatal }
    }
  }

  it 'makes a test bot' do
    expect(bot).to be_a Cinch::Bot
  end

  describe '!declare' do
    let(:message) { make_message(bot, '!declare aa', channel: '#test') }

    before :each do
      @conn = FakeConnection.new
      @tyrant = Tyrants.get_fake('testplayer', @conn)
      expect(Tyrants).to receive(:get).with('testplayer').and_return(@tyrant)
      allow(message.user).to receive(:master?).and_return(true)
    end

    it 'refuses if there is nobody with this name' do
      @conn.respond('getFactionRivals', 'name=aa', {'rivals' => []})
      replies = get_replies_text(message)
      expect(replies).to be == ['No, there is nobody with that name']
    end

    it 'refuses if the request is ambiguous' do
      @conn.respond('getFactionRivals', 'name=aa', {'rivals' => [
        {
          'faction_id' => '2001',
          'rating' => '1',
          'name' => 'baa',
          'infamy_gain' => 0,
          'less_rating_time' => 0,
        },
        {
          'faction_id' => '2002',
          'rating' => '2',
          'name' => 'kaa',
          'infamy_gain' => 0,
          'less_rating_time' => 0,
        },
      ]})
      replies = get_replies_text(message)
      expect(replies).to be == ['No, that is ambiguous, 2']
    end

    it 'refuses if the declaration would incur infamy' do
      @conn.respond('getFactionRivals', 'name=aa', {'rivals' => [
        {
          'faction_id' => '2001',
          'rating' => '1',
          'name' => 'baa',
          'infamy_gain' => 1,
          'less_rating_time' => 0,
        },
      ]})
      replies = get_replies_text(message)
      expect(replies).to be == ['No, that would get us infamy']
    end

    context 'when declaration would earn less FP' do
      before :each do
        @conn.respond('getFactionRivals', 'name=aa', {'rivals' => [
          {
            'faction_id' => '2001',
            'rating' => '1',
            'name' => 'baa',
            'infamy_gain' => 0,
            'less_rating_time' => Time.now.to_i,
          },
        ]})
      end

      it 'refuses if the declaration would earn less FP' do
        replies = get_replies_text(message)
        expect(replies).to be == ['Are you sure? That would give reduced FP']
      end

      it 'declares with confirmation' do
        m = make_message(bot, '!declare --yes-really aa', channel: '#test')
        allow(m.user).to receive(:master?).and_return(true)
        @conn.respond(
          'declareFactionWar', 'target_faction_id=2001&infamy_gain=0',
          {'result' => true, 'war_info' => make_war(1)}
        )
        replies = get_replies_text(m)
        expect(replies.shift).to be =~
          /^\s*1 - faction 1000 vs THE ENEMY 0-0 \(\+0\) \d\d:\d\d:\d\d left$/
        expect(replies).to be == []
      end
    end

    it 'declares the war if everything is fine' do
      @conn.respond('getFactionRivals', 'name=aa', {'rivals' => [
        {
          'faction_id' => '2001',
          'rating' => '1',
          'name' => 'baa',
          'infamy_gain' => 0,
          'less_rating_time' => 0,
        },
      ]})
      @conn.respond(
        'declareFactionWar', 'target_faction_id=2001&infamy_gain=0',
        {'result' => true, 'war_info' => make_war(1)}
      )
      replies = get_replies_text(message)
      expect(replies.shift).to be =~
        /^\s*1 - faction 1000 vs THE ENEMY 0-0 \(\+0\) \d\d:\d\d:\d\d left$/
      expect(replies).to be == []
    end

    it 'warns if something went wrong when declaring' do
      @conn.respond('getFactionRivals', 'name=aa', {'rivals' => [
        {
          'faction_id' => '2001',
          'rating' => '1',
          'name' => 'baa',
          'infamy_gain' => 0,
          'less_rating_time' => 0,
        },
      ]})
      failure = { 'result' => false }
      @conn.respond(
        'declareFactionWar', 'target_faction_id=2001&infamy_gain=0',
        failure
      )
      expect(bot.plugins.first).to receive(:warn).with(failure.to_s)
      replies = get_replies_text(message)
      expect(replies).to be == [false]
    end
  end
end
