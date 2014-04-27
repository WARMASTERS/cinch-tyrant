require_relative 'test-common'

require 'cinch/plugins/tyrant-tile'

describe Cinch::Plugins::TyrantTile do
  include Cinch::Test

  let(:bot) {
    make_bot(Cinch::Plugins::TyrantTile, {:checker => 'checker'}) { |c|
      self.loggers.stub('debug') { nil }
    }
  }

  before :each do
    @conn = FakeConnection.new
    @tyrant = Tyrants.get_fake('checker', @conn)
    expect(Tyrants).to receive(:get).with('checker').and_return(@tyrant)
    @conn.respond('getConquestMap', '', {'conquest_map' => {'map' => [
      make_tile(1, 1000, x: 1, y: 2),
      make_tile(2, 1001, x: 3, y: 4),
      make_tile(3, 1002, x: 5, y: 6),
    ]}})
  end

  it 'makes a test bot' do
    expect(bot).to be_a Cinch::Bot
  end

  # TODO: !tile -v

  describe '!tile by coordinates' do
    let(:message) { make_message(bot, '!tile 1e2s', channel: '#test') }

    it 'looks up the tile and uses its ID' do
      expect(bot.plugins[0]).to receive(:tile).with(message, nil, 1)
      get_replies(message)
    end
  end

  describe "!tile on someone else's uncontested tile" do
    before :each do
      @conn = FakeConnection.new
      @tyrant = Tyrants.get_fake('testplayer', @conn)
      expect(Tyrants).to receive(:get).with('testplayer').and_return(@tyrant)
    end

    let(:message) { make_message(bot, '!tile 2', channel: '#test') }

    it 'shows tile info' do
      bot.plugins[0].stub(:shared).and_return({:conquest_map_hash => {
        '1' => make_tile(1, 1000, x: 1, y: 2),
        '2' => make_tile(2, 1001, x: 3, y: 4),
        '3' => make_tile(3, 1002, x: 5, y: 6),
      }})
      replies = get_replies_text(message)
      expect(replies).to be == [' 3E,  4S: faction 1001, CR: 1']
    end
  end

  describe '!tile on my uncontested tile' do
    before :each do
      @conn = FakeConnection.new
      @tyrant = Tyrants.get_fake('testplayer', @conn)
      expect(Tyrants).to receive(:get).with('testplayer').and_return(@tyrant)
      bot.plugins[0].stub(:shared).and_return({:conquest_map_hash => {
        '1' => make_tile(1, 1000, x: 1, y: 2),
        '2' => make_tile(2, 1001, x: 3, y: 4),
        '3' => make_tile(3, 1002, x: 5, y: 6),
      }})
    end

    let(:message) { make_message(bot, '!tile 1', channel: '#test') }

    it 'shows tile info on tile with decks' do
      @conn.respond('getConquestTileInfo', 'system_id=1', {'system' => {
        'max_health' => 100,
        'slots' => {
          '1' => {'commander_id' => 1000, 'health' => '100', 'defeated' => '0'},
        },
      }})
      replies = get_replies_text(message)
      expect(replies).to be == [
        ' 1E,  2S: faction 1000, CR: 1',
        '1/1 (100.00%) slots alive. 100/100 (100.00%) health left.'
      ]
    end

    it 'shows tile info on tile with no decks' do
      @conn.respond('getConquestTileInfo', 'system_id=1', {'system' => {
        'max_health' => 100,
        'slots' => {},
      }})
      replies = get_replies_text(message)
      expect(replies).to be == [
        ' 1E,  2S: faction 1000, CR: 1',
        # TODO: Do we really want this kind of output?!
        '0/0 (NaN%) slots alive. 0/0 (NaN%) health left.'
      ]
    end
  end

  # TODO: !tile on a tile we're attacking, or we're defending
end
