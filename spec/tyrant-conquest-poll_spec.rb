require_relative 'test-common'

require 'cinch/plugins/tyrant-conquest-poll'

describe Cinch::Plugins::TyrantConquestPoll do
  include Cinch::Test

  let(:bot) {
    opts = {
      :poller => 'poller',
      :report_channel => '#conquest-news',
    }
    make_bot(Cinch::Plugins::TyrantConquestPoll, opts) { |c|
      self.loggers.stub('debug') { nil }
    }
  }

  let(:my_channel) { '#test' }
  let(:news_channel) { '#conquest-news' }

  before :each do
    @conn = FakeConnection.new
    @conn2 = FakeConnection.new
    @tyrant = Tyrants.get_fake('poller', @conn)
    @tyrant2 = Tyrants.get_fake('testplayer', @conn2)
    expect(Tyrants).to receive(:get).with('poller').and_return(@tyrant)
    expect(Tyrants).to receive(:get).with('testplayer').and_return(@tyrant2)
    @conn.respond('getConquestMap', '', {'conquest_map' => {'map' => [
      make_tile(1, 1000),
      make_tile(2, 1001),
    ]}})

    @chans = {
      news_channel => FakeChannel.new,
      my_channel => FakeChannel.new,
    }

    bot.plugins[0].stub(:Channel) { |n| @chans[n] }
  end

  it 'makes a test bot' do
    expect(bot).to be_a Cinch::Bot
  end

  shared_examples 'gaining a tile' do
    it 'notifies my faction channel' do
      expect(@chans[my_channel].messages.shift).to be ==
        '[CONQUEST]    2 (  0,   0) Conquered from faction 1001'
      expect(@chans[my_channel].messages).to be == []
    end

    it 'notifies the news channel' do
      expect(@chans[news_channel].messages.shift).to be ==
        '[CONQUEST]    2 (  0,   0) faction 1001[1001] -> faction 1000[1000]'
      expect(@chans[news_channel].messages).to be == []
    end
  end

  shared_examples 'losing a tile' do
    it 'notifies my faction channel' do
      expect(@chans[my_channel].messages.shift).to be ==
        '[CONQUEST]    1 (  0,   0) Lost to faction 1001'
      expect(@chans[my_channel].messages).to be == []
    end

    it 'notifies the news channel' do
      expect(@chans[news_channel].messages.shift).to be ==
        '[CONQUEST]    1 (  0,   0) faction 1000[1000] -> faction 1001[1001]'
      expect(@chans[news_channel].messages).to be == []
    end
  end

  context 'when my faction invades a defended tile' do
    before(:each) do
      @conn.respond('getConquestMap', '', {'conquest_map' => {'map' => [
        make_tile(1, 1000),
        make_tile(2, 1001, 1000),
      ]}})
      bot.plugins[0].get_timers[0].fire!
    end

    it 'notifies my faction channel' do
      expect(@chans[my_channel].messages.shift).to be ==
        '[CONQUEST]    2 (  0,   0) New invasion against faction 1001'
      expect(@chans[my_channel].messages).to be == []
    end

    it 'notifies the news channel' do
      expect(@chans[news_channel].messages.shift).to be ==
        '[CONQUEST]    2 (  0,   0) faction 1001[1001] invaded by faction 1000[1000]'
      expect(@chans[news_channel].messages).to be == []
    end

    context 'winning the invasion' do
      before(:each) do
        @chans.each_value { |c| c.messages.clear }
        @conn.respond('getConquestMap', '', {'conquest_map' => {'map' => [
          make_tile(1, 1000),
          make_tile(2, 1000),
        ]}})
        bot.plugins[0].get_timers[0].fire!
      end

      it_behaves_like 'gaining a tile'
    end
  end

  context 'when my faction defends a tile' do
    before(:each) do
      @conn.respond('getConquestMap', '', {'conquest_map' => {'map' => [
        make_tile(1, 1000, 1001),
        make_tile(2, 1001),
      ]}})
      bot.plugins[0].get_timers[0].fire!
    end

    it 'notifies my faction channel' do
      expect(@chans[my_channel].messages.shift).to be ==
        '[CONQUEST]    1 (  0,   0) Under attack by faction 1001'
      expect(@chans[my_channel].messages).to be == []
    end

    it 'notifies the news channel' do
      expect(@chans[news_channel].messages.shift).to be ==
        '[CONQUEST]    1 (  0,   0) faction 1000[1000] invaded by faction 1001[1001]'
      expect(@chans[news_channel].messages).to be == []
    end

    context 'losing the defense' do
      before(:each) do
        @chans.each_value { |c| c.messages.clear }
        @conn.respond('getConquestMap', '', {'conquest_map' => {'map' => [
          make_tile(1, 1001),
          make_tile(2, 1001),
        ]}})
        bot.plugins[0].get_timers[0].fire!
      end

      it_behaves_like 'losing a tile'
    end
  end

  context 'when my faction invades an undefended tile' do
    before(:each) do
      @conn.respond('getConquestMap', '', {'conquest_map' => {'map' => [
        make_tile(1, 1000),
        make_tile(2, 1000),
      ]}})
      bot.plugins[0].get_timers[0].fire!
    end

    it_behaves_like 'gaining a tile'
  end

  context 'when my faction loses an undefended tile' do
    before(:each) do
      @conn.respond('getConquestMap', '', {'conquest_map' => {'map' => [
        make_tile(1, 1001),
        make_tile(2, 1001),
      ]}})
      bot.plugins[0].get_timers[0].fire!
    end

    it_behaves_like 'losing a tile'
  end

  describe 'invasion notifications' do
    before(:each) do
      @conn.respond('getConquestMap', '', {'conquest_map' => {'map' => [
        make_tile(1, 1000),
        make_tile(2, 1001, 1000),
      ]}})
      @conn2.respond('getConquestTileInfo', 'system_id=2', {'system' => {
        'slots' => {
          '1' => {'commander_id' => 1000, 'health' => '100', 'defeated' => '0'},
        },
      }})
      bot.plugins[0].get_timers[0].fire!
      @chans.each_value { |c| c.messages.clear }
      bot.plugins[0].get_timers[1].fire!

      Cinch::Plugins::TyrantConquestPoll.stub(:cards).and_return({
        1000 => FakeCard.new(1000, 'Cyrus'),
        1001 => FakeCard.new(1001, 'Whisper'),
      })
    end

    it 'Notifies on commander change' do
      @conn2.respond('getConquestTileInfo', 'system_id=2', {'system' => {
        'slots' => {
          '1' => {'commander_id' => 1001, 'health' => '100', 'defeated' => '0'},
        },
      }})
      bot.plugins[0].get_timers[1].fire!
      expect(@chans[my_channel].messages.shift).to be ==
        '[INVASION] Slot 1 (100 HP) commander changed from Cyrus to Whisper'
      expect(@chans[my_channel].messages).to be == []
    end

    it 'Notifies on commander death' do
      @conn2.respond('getConquestTileInfo', 'system_id=2', {'system' => {
        'slots' => {
          '1' => {'commander_id' => 1000, 'health' => '0', 'defeated' => '1'},
        },
      }})
      bot.plugins[0].get_timers[1].fire!
      expect(@chans[my_channel].messages.shift).to be ==
        '[INVASION] Slot 1 (Cyrus) has been defeated!'
      expect(@chans[my_channel].messages).to be == []
    end
  end

  describe 'conquest map reset' do
    before :each  do
      # map is set in top-level before :each, and plugin ctor has been run.

      # And suddenly, the map has no owners! Fire timer again.
      @conn.respond('getConquestMap', '', {'conquest_map' => {'map' => [
        make_tile(1),
        make_tile(2),
      ]}})
      bot.plugins[0].get_timers[0].fire!
    end

    it 'notifies faction channel when the map resets' do
      expect(@chans[my_channel].messages).to be == ['[CONQUEST] MAP RESET!!!']
    end

    it 'notifies news channel when the map resets' do
      expect(@chans[news_channel].messages).to be == ['[CONQUEST] MAP RESET!!!']
    end

    context 'when map is still unoccupied after a second timer fire' do
      before :each do
        @chans.each_value { |c| c.messages.clear }

        # Map is still blank
        @conn.respond('getConquestMap', '', {'conquest_map' => {'map' => [
          make_tile(1),
          make_tile(2),
        ]}})
        bot.plugins[0].get_timers[0].fire!
      end

      it 'does not notify faction channel a second time' do
        expect(@chans[my_channel].messages).to be == []
      end

      it 'does not notify news channel a second time' do
        expect(@chans[news_channel].messages).to be == []
      end
    end
  end

  # TODO: conquest news options
end
