require_relative 'test-common'

require 'cinch/plugins/tyrant-say'

describe Cinch::Plugins::TyrantSay do
  include Cinch::Test

  let(:bot) {
    make_bot(Cinch::Plugins::TyrantSay) { |c|
      self.loggers.stub('debug') { nil }
    }
  }

  it 'makes a test bot' do
    expect(bot).to be_a Cinch::Bot
  end

  # TODO: !tile -v

  describe 'say' do
    before :each do
      @conn = FakeConnection.new
      @tyrant = Tyrants.get_fake('testplayer', @conn)
      expect(Tyrants).to receive(:get).with('testplayer').and_return(@tyrant)
      bot.plugins[0].stub(:is_superofficer?).and_return(true)
      message.user.stub(:master?).and_return(false)
    end

    let(:message) { make_message(bot, '!say something', channel: '#test') }

    it 'says something' do
      # Abstraction leak here: I should not have to escape [, ], or /
      @conn.respond('postFactionMessage', 'text=\[IRC\/test\] something', {
        # lolwut why does Tyrant send nil?
        'result' => nil,
      })
      replies = get_replies_text(message)
      expect(replies).to be == ['test: Your message was posted.']
    end

    it 'handles failure to post' do
      # Abstraction leak here: I should not have to escape [, ], or /
      @conn.respond('postFactionMessage', 'text=\[IRC\/test\] something', {
        'result' => false,
      })
      replies = get_replies_text(message)
      expect(replies).to be == ['test: Your message was NOT posted.']
    end
  end
end
