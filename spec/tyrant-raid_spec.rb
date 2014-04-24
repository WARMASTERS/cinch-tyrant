require_relative 'test-common'

require 'cinch/plugins/tyrant-raids'

describe Cinch::Plugins::TyrantRaids do
  include Cinch::Test

  let(:bot) {
    make_bot(Cinch::Plugins::TyrantRaids, {:checker => 'testplayer'}) { |c|
      self.loggers.stub('debug') { nil }
    }
  }

  before :each do
    expect(Tyrant).to receive(:parse_raids).and_return([
      Tyrant::Raid.new(0, 'Raid 0 WTF', 1, 1, 1, 1),
      Tyrant::Raid.new(1, 'The First Raid', 5, 100, 7200, 1000)
    ])
  end

  it 'makes a test bot' do
    expect(bot).to be_a Cinch::Bot
  end

  describe '!raid by username' do
    let(:message) { make_message(bot, '!raid joe', channel: '#test') }

    it 'looks up the user and uses that ID' do
      expect(Tyrant).to receive(:get_id_of_name).with('joe').and_return(93)
      expect(bot.plugins[0]).to receive(:raid_id).with(message, nil, 93)
      get_replies(message)
    end
  end

  describe '!raid by ID' do
    let(:message) { make_message(bot, '!raid 1234', channel: '#test') }

    before :each do
      @conn = FakeConnection.new
      @tyrant = Tyrants.get_fake('testplayer', @conn)
      expect(Tyrants).to receive(:get).with('testplayer').and_return(@tyrant)
    end

    it 'looks up the user and uses that ID' do
      expect(Tyrant).to receive(:get_name_of_id).with('1234').and_return('someone')
      @conn.respond('getRaidInfo', 'user_raid_id=1234', {'raid_info' => {
        'user_raid_id' => '1234',
        'raid_id' => '1',
        'user_id' => '1',
        'end_time' => Time.now.to_i + 3600,
        'health' => '100',
        'raid_members' => [],
      }})
      replies = get_replies_text(message)
      expect(replies.shift).to be =~
        /someone's The First Raid: 0\/5, 100\/100 \(100%\), \d\d:\d\d\/2 hours \(50%\)/
      expect(replies).to be == []
    end
  end

  describe '!raid -u by username that looks like ID' do
    let(:message) { make_message(bot, '!raid -u 1234', channel: '#test') }

    it 'looks up the user and uses that ID' do
      expect(Tyrant).to receive(:get_id_of_name).with('1234').and_return(431)
      expect(bot.plugins[0]).to receive(:raid_id).with(message, '-u ', 431)
      get_replies(message)
    end
  end

  describe '!raids' do
    before :each do
      @conn = FakeConnection.new
      @tyrant = Tyrants.get_fake('testplayer', @conn)
      expect(Tyrants).to receive(:get).with('testplayer').and_return(@tyrant)
    end

    let(:message) { make_message(bot, '!raids 1', channel: '#test') }

    it 'informs the user when there are no raids' do
      @conn.respond('getPublicRaids', 'raid_id=1', {'public_raids' => []})
      replies = get_replies_text(message)
      expect(replies).to be == ['Sorry, there are no public The First Raid']
    end

    it 'shows some raids' do
      @conn.respond('getPublicRaids', 'raid_id=1', {'public_raids' => [{
        'user_raid_id' => '5678',
        'raid_id' => '1',
        'start_time' => Time.now.to_i.to_s,
        'health' => '10',
        'num_members' => '2',
      }]})
      expect(Tyrant).to receive(:get_name_of_id).with('5678').and_return('mytest')
      replies = get_replies_text(message)
      expect(replies.shift).to be =~
        /5678 mytest's The First Raid: 2\/5, 10\/100 \(10%\), \d\d:\d\d\/2 hours \(100%\)/
      expect(replies).to be == []
    end
  end

  describe '!fraids' do
    # TODO fraids tests
  end
end
