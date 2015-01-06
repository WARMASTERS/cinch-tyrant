require_relative 'test-common'

require 'cinch/plugins/tyrant-register'

describe Cinch::Plugins::TyrantRegister do
  include Cinch::Test

  let(:bot) {
    make_bot(Cinch::Plugins::TyrantRegister, {:helpfile => 'blahblah2'}) { |c|
      self.loggers.each { |l| l.level = :fatal }
    }
  }

  it 'makes a test bot' do
    expect(bot).to be_a Cinch::Bot
  end

  describe '!register' do
    let(:message) { make_message(bot, '!register', channel: '#test') }

    it 'shows a known user the help file' do
      replies = get_replies_text(message)
      expect(replies).to be == ['blahblah2']
    end

    it 'stays silent for an unknown user' do
      allow(bot.plugins[0]).to receive(:is_friend?).and_return(false)
      replies = get_replies_text(message)
      expect(replies).to be == []
    end
  end
end
