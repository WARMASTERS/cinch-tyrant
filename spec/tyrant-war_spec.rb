require_relative 'test-common'

require 'cinch/plugins/tyrant-war'

describe Cinch::Plugins::TyrantWar do
  include Cinch::Test

  let(:bot) {
    make_bot(Cinch::Plugins::TyrantWar) { |c|
      self.loggers.each { |l| l.level = :fatal }
    }
  }
  let(:plugin) { bot.plugins.first }

  before :each do
    @conn = FakeConnection.new
    @tyrant = Tyrants.get_fake('testplayer', @conn)
    expect(Tyrants).to receive(:get).with('testplayer').and_return(@tyrant)
  end

  describe '!war' do
    let(:message) { make_message(bot, '!war', channel: '#test') }

    it 'informs the user when there are no wars' do
      @conn.respond('getActiveFactionWars', '', {'wars' => {}})
      replies = get_replies_text(message)
      expect(replies).to be == ['No wars!']
    end

    it 'shows wars' do
      @conn.respond('getActiveFactionWars', '', {'wars' => {
        '1' => make_war(1),
      }})
      replies = get_replies_text(message)
      expect(replies.shift).to be =~
        /^\s*1 - faction 1000 vs THE ENEMY 0-0 \(\+0\) \d\d:\d\d:\d\d left$/
      expect(replies).to be == []
    end
  end

  describe '!war <id>' do
    let(:message) { make_message(bot, '!war 1', channel: '#test') }

    # TODO: If ID is invalid?

    it 'shows war stats for a current war' do
      @conn.respond('getFactionWarInfo', 'faction_war_id=1', make_war(1))
      @conn.respond('getOldFactionWars', '', {'wars' => []})
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

    it 'shows war stats for an ended war' do
      @conn.respond('getFactionWarInfo', 'faction_war_id=1', make_war(1))
      @conn.respond('getOldFactionWars', '', {'wars' => [make_war(1)]})
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

  describe '!war -v <id>' do
    let(:message) { make_message(bot, '!war -v 1', channel: '#test') }

    it 'shows war stats for a current war' do
      @conn.respond('getFactionWarInfo', 'faction_war_id=1', make_war(1))
      @conn.respond('getOldFactionWars', '', {'wars' => []})
      @conn.respond('getFactionWarRankings', 'faction_war_id=1', {'rankings' => {
        '1000' => {},
        '1001' => {},
      }})
      replies = get_replies_text(message)
      expect(replies.shift).to be =~
        /^\s*1 - faction 1000 vs THE ENEMY 0-0 \(\+0\) \d\d:\d\d:\d\d left$/
      # TODO: eh, somewhat better checking
      expect(replies.shift).to be =~ /Inactive players/
      expect(replies).to be == []
    end
  end

  describe '!war <id> <player> with invalid player' do
    let(:message) { make_message(bot, '!war 1 joecool', channel: '#test') }
    before :each do
      expect(Tyrant).to receive(:id_of_name).with('joecool').and_return(nil)
    end

    it 'displays the war, then says player not found' do
      @conn.respond('getFactionWarInfo', 'faction_war_id=1', make_war(1))
      @conn.respond('getOldFactionWars', '', {'wars' => []})
      @conn.respond('getFactionWarRankings', 'faction_war_id=1', {'rankings' => {
        '1000' => {},
        '1001' => {},
      }})
      replies = get_replies_text(message)
      expect(replies.shift).to be =~
        /^\s*1 - faction 1000 vs THE ENEMY 0-0 \(\+0\) \d\d:\d\d:\d\d left$/
      expect(replies).to be == ['joecool not found']
    end
  end

  describe '!war <id> <player>' do
    let(:message) { make_message(bot, '!war 1 joecool', channel: '#test') }
    before :each do
      expect(Tyrant).to receive(:id_of_name).with('joecool').and_return(47)
    end

    it 'says when player has not participated' do
      @conn.respond('getFactionWarInfo', 'faction_war_id=1', make_war(1))
      @conn.respond('getOldFactionWars', '', {'wars' => []})
      @conn.respond('getFactionWarRankings', 'faction_war_id=1', {'rankings' => {
        '1000' => {},
        '1001' => {},
      }})
      replies = get_replies_text(message)
      expect(replies.shift).to be =~
        /^\s*1 - faction 1000 vs THE ENEMY 0-0 \(\+0\) \d\d:\d\d:\d\d left$/
      expect(replies).to be == ['joecool has not participated in this war']
    end

    it 'says when player is in faction' do
      @conn.respond('getFactionWarInfo', 'faction_war_id=1', make_war(1))
      @conn.respond('getOldFactionWars', '', {'wars' => []})
      @conn.respond('getFactionWarRankings', 'faction_war_id=1', {'rankings' => {
        '1000' => [make_war_ranking(47, 1, 0, 45, 2)],
        '1001' => {},
      }})
      replies = get_replies_text(message)
      expect(replies.shift).to be =~
        /^\s*1 - faction 1000 vs THE ENEMY 0-0 \(\+0\) \d\d:\d\d:\d\d left$/
      expect(replies).to be == [
        'joecool (faction 1000): Attack 1W/0L, Defense 0W/0L, +45 -2 = +43'
      ]
    end

    it 'says when player is opponent' do
      @conn.respond('getFactionWarInfo', 'faction_war_id=1', make_war(1))
      @conn.respond('getOldFactionWars', '', {'wars' => []})
      @conn.respond('getFactionWarRankings', 'faction_war_id=1', {'rankings' => {
        '1000' => {},
        '1001' => [make_war_ranking(47, 1, 0, 45, 2)],
      }})
      replies = get_replies_text(message)
      expect(replies.shift).to be =~
        /^\s*1 - faction 1000 vs THE ENEMY 0-0 \(\+0\) \d\d:\d\d:\d\d left$/
      expect(replies).to be == [
        'joecool (THE ENEMY): Attack 1W/0L, Defense 0W/0L, +45 -2 = +43'
      ]
    end
  end

  shared_examples '!ws command' do
    context 'when faction is in no wars' do
      before :each do
        @conn.respond('getActiveFactionWars', '', {'wars' => {}})
      end

      it 'shows no wars' do
        allow(plugin).to receive(:warstats)
        replies = get_replies_text(message)
        expect(replies).to be == ['No wars!']
      end
    end

    context 'when faction is in one war' do
      before :each do
        @war = make_war(1)
        @conn.respond('getActiveFactionWars', '', {'wars' => {
          '1' => @war,
        }})
      end

      it 'shows wars' do
        allow(plugin).to receive(:warstats)
        replies = get_replies_text(message)
        expect(replies.shift).to be =~
          /^\s*1 - faction 1000 vs THE ENEMY 0-0 \(\+0\) \d\d:\d\d:\d\d left$/
      end

      it 'shows stats' do
        expect(plugin).to receive(:warstats).with(anything, '1', player, 0, {
          :show_score => false, :opponent_name => @war['name'],
        })
        get_replies(message)
      end
    end

    context 'when faction is in multiple wars' do
      before :each do
        @war1 = make_war(1)
        @war2 = make_war(2)
        @conn.respond('getActiveFactionWars', '', {'wars' => {
          '1' => @war1,
          '2' => @war2,
        }})
      end

      it 'shows wars' do
        replies = get_replies_text(message)
        expect(replies.shift).to be =~ /More than one war/
        wars = replies.shift
        expect(wars).to be =~
          /^\s*1 - faction 1000 vs THE ENEMY 0-0 \(\+0\) \d\d:\d\d:\d\d left$/
        expect(wars).to be =~
          /^\s*2 - faction 1000 vs THE ENEMY 0-0 \(\+0\) \d\d:\d\d:\d\d left$/
        expect(replies).to be == []
      end

      it 'does not show stats' do
        expect(plugin).to_not receive(:warstats)
        get_replies(message)
      end
    end
  end

  describe '!ws' do
    let(:message) { make_message(bot, '!ws', channel: '#test') }
    let(:player) { nil }

    it_behaves_like '!ws command'
  end

  describe '!ws <player>' do
    let(:message) { make_message(bot, '!ws joecool', channel: '#test') }
    let(:player) { 'joecool' }

    it_behaves_like '!ws command'
  end
end
