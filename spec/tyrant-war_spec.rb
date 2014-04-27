require_relative 'test-common'

require 'cinch/plugins/tyrant-war'

describe Cinch::Plugins::TyrantWar do
  include Cinch::Test

  let(:bot) {
    make_bot(Cinch::Plugins::TyrantWar) { |c|
      self.loggers.stub('debug') { nil }
    }
  }

  it 'makes a test bot' do
    expect(bot).to be_a Cinch::Bot
  end

  describe '!war' do
    before :each do
      @conn = FakeConnection.new
      @tyrant = Tyrants.get_fake('testplayer', @conn)
      expect(Tyrants).to receive(:get).with('testplayer').and_return(@tyrant)
    end

    let(:message) { make_message(bot, '!war', channel: '#test') }

    it 'informs the user when there are no wars' do
      @conn.respond('getActiveFactionWars', '', {'wars' => {}})
      replies = get_replies_text(message)
      expect(replies).to be == ['No wars!']
    end

    it 'shows wars' do
      @conn.respond('getActiveFactionWars', '', {'wars' => {
        '1' => {
          'faction_war_id' => '1',
          'name' => 'THE ENEMY',
          'attacker_faction_id' => '1000',
          'defender_faction_id' => '1001',
          'start_time' => Time.now.to_i.to_s,
          'duration' => '6',
          'atk_pts' => '0',
          'def_pts' => '0',
        },
      }})
      replies = get_replies_text(message)
      expect(replies.shift).to be =~
        /^\s*1 - faction 1000 vs THE ENEMY 0-0 \(\+0\) \d\d:\d\d:\d\d left$/
      expect(replies).to be == []
    end
  end

  describe '!war <id>' do
    before :each do
      @conn = FakeConnection.new
      @tyrant = Tyrants.get_fake('testplayer', @conn)
      expect(Tyrants).to receive(:get).with('testplayer').and_return(@tyrant)
    end

    let(:message) { make_message(bot, '!war 1', channel: '#test') }

    # TODO: If ID is invalid?

    it 'shows war stats' do
      @conn.respond('getFactionWarInfo', 'faction_war_id=1', {
        'faction_war_id' => '1',
        'name' => 'THE ENEMY',
        'attacker_faction_id' => '1000',
        'defender_faction_id' => '1001',
        'start_time' => Time.now.to_i.to_s,
        'duration' => '6',
        'atk_pts' => '0',
        'def_pts' => '0',
      })
      @conn.respond('getOldFactionWars', '', {'wars' => {
      }})
      @conn.respond('getFactionWarRankings', 'faction_war_id=1', {'rankings' => {
        '1000' => {},
        '1001' => {},
      }})
      replies = get_replies_text(message)
      expect(replies.shift).to be =~
        /^\s*1 - faction 1000 vs THE ENEMY 0-0 \(\+0\) \d\d:\d\d:\d\d left$/
      # TODO: eh, somewhat better checking
      expect(replies.shift).to be =~ /Active players/
      expect(replies).to be == []
    end
  end

  # TODO: !war <id> <player>
  # TODO: !war -v <id>
  # TODO: !ws
end
