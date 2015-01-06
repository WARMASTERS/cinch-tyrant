require_relative 'test-common'

require 'cinch/plugins/tyrant-faction-chat'

describe Cinch::Plugins::TyrantFactionChat do
  include Cinch::Test

  let(:config) {{
  }}

  let(:bot) {
    make_bot(Cinch::Plugins::TyrantFactionChat, config) { |c|
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
    allow(bot.plugins[0]).to receive(:Channel).and_return(@chan)
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
      expect(Tyrant).to receive(:name_of_id).with('2').and_return('usertwo')
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

  shared_examples 'posting two messages in the right order' do
    before :each do
      @conn.respond('getNewFactionMessages', 'last_post=60', {'messages' =>
        two_messages,
      })
      expect(Tyrant).to receive(:name_of_id).with('2').twice.and_return('usertwo')
      bot.plugins[0].get_timers[0].fire!
    end

    it 'posts new messages' do
      expect(@chan.messages).to be == [
        '[FACTION] usertwo: m2',
        '[FACTION] usertwo: m3',
      ]
    end

    it 'updates last post before doing next poll' do
      @conn.respond('getNewFactionMessages', 'last_post=62', {'messages' => []})
      bot.plugins[0].get_timers[0].fire!
    end
  end

  context 'with two new messages in the right order' do
    let(:two_messages) {[
      {'post_id' => '61', 'message' => 'm2', 'user_id' => '2'},
      {'post_id' => '62', 'message' => 'm3', 'user_id' => '2'},
    ]}

    it_behaves_like 'posting two messages in the right order'
  end

  context 'with two new messages in reversed order' do
    let(:two_messages) {[
      {'post_id' => '62', 'message' => 'm3', 'user_id' => '2'},
      {'post_id' => '61', 'message' => 'm2', 'user_id' => '2'},
    ]}

    it_behaves_like 'posting two messages in the right order'
  end

  context 'with filters' do
    let(:config) {{
      :filters => { '#test' => ['required', 'words'] }
    }}

    before :each do
      @conn.respond('getNewFactionMessages', 'last_post=60', {'messages' => [
        {'post_id' => '61', 'message' => 'non', 'user_id' => '2'},
        {'post_id' => '62', 'message' => 'required', 'user_id' => '2'},
        {'post_id' => '63', 'message' => 'words here', 'user_id' => '2'},
      ]})
      allow(Tyrant).to receive(:name_of_id).with('2').and_return('usertwo')
      bot.plugins[0].get_timers[0].fire!
    end

    it 'posts only messages that match a filter' do
      expect(@chan.messages).to be == [
        '[FACTION] usertwo: required',
        '[FACTION] usertwo: words here',
      ]
    end
  end

  # TODO: !chat (on|off)
end
