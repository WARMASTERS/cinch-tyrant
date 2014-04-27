require_relative 'test-common'

require 'cinch/plugins/tyrant-history'

describe Cinch::Plugins::TyrantHistory do
  include Cinch::Test

  let(:bot) {
    make_bot(Cinch::Plugins::TyrantHistory) { |c|
      self.loggers.stub('debug') { nil }
    }
  }

  before :each do
    @conn = FakeConnection.new
    @tyrant = Tyrants.get_fake('testplayer', @conn)
    allow(Tyrants).to receive(:get).with('testplayer').and_return(@tyrant)
  end

  it 'makes a test bot' do
    expect(bot).to be_a Cinch::Bot
  end

  it 'shows old wars' do
    @conn.respond('getOldFactionWars', '', {'wars' => [
      {
        'faction_war_id' => '1',
        'name' => 'THE ENEMY',
        'attacker_faction_id' => '1000',
        'defender_faction_id' => '1001',
        'start_time' => Time.now.to_i.to_s,
        'duration' => '6',
        'atk_pts' => '0',
        'def_pts' => '0',
      },
    ]})

    msg = make_message(bot, '!last', channel: '#test')
    replies = get_replies_text(msg)
    expect(replies).to be == ['         1 - faction 1000 vs THE ENEMY 0-0 (+0) 06:00:00 left']
  end

  describe 'flood control' do
    def msg
      make_message(bot, '!last', channel: '#test')
    end

    before :each do
      @conn.respond('getOldFactionWars', '', {'wars' => [
        {
          'faction_war_id' => '1',
          'name' => 'THE ENEMY',
          'attacker_faction_id' => '1000',
          'defender_faction_id' => '1001',
          'start_time' => Time.now.to_i.to_s,
          'duration' => '6',
          'atk_pts' => '0',
          'def_pts' => '0',
        },
      ]})
    end

    it 'warns on second' do
      get_replies(msg)
      replies = get_replies_text(msg)
      expect(replies).to be == ['test: Requesting history too often. Cool down a bit.']
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
