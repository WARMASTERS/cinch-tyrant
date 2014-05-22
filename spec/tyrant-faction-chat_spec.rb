require_relative 'test-common'

require 'cinch/plugins/tyrant-faction-chat'

describe Cinch::Plugins::TyrantFactionChat do
  include Cinch::Test

  let(:bot) {
    make_bot(Cinch::Plugins::TyrantFactionChat) { |c|
      self.loggers.stub('debug') { nil }
    }
  }

  before :each do
    @conn = FakeConnection.new
    @tyrant = Tyrants.get_fake('testplayer', @conn)
    expect(Tyrants).to receive(:get).with('testplayer').and_return(@tyrant)
    @conn.respond('getFactionMessages', '', {'messages' => [
      {'post_id' => '60', 'message' => 'm1', 'user_id' => '1'},
    ]})
    @chan = FakeChannel.new
    bot.plugins[0].stub(:Channel).and_return(@chan)
  end

  it 'makes a test bot' do
    expect(bot).to be_a Cinch::Bot
  end

  it 'does nothing if there are no new messages' do
    @conn.respond('getNewFactionMessages', 'last_post=60', {'messages' => []})
    bot.plugins[0].get_timers[0].fire!
    expect(@chan.messages).to be == []
  end

  context 'with new messages' do
    before :each do
      @conn.respond('getNewFactionMessages', 'last_post=60', {'messages' => [
        {'post_id' => '61', 'message' => 'm2', 'user_id' => '2'},
      ]})
      expect(Tyrant).to receive(:get_name_of_id).with('2').and_return('usertwo')
      bot.plugins[0].get_timers[0].fire!
    end

    it 'posts new messages' do
      expect(@chan.messages).to be == ['[FACTION] usertwo: m2']
    end

    it 'updates last post before doing next poll' do
      @conn.respond('getNewFactionMessages', 'last_post=61', {'messages' => []})
      bot.plugins[0].get_timers[0].fire!
    end
  end

  # TODO: !chat (on|off)
end
