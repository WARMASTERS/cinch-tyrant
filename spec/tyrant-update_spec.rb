require_relative 'test-common'

require 'cinch/plugins/tyrant-update'

describe Cinch::Plugins::TyrantUpdate do
  include Cinch::Test

  let(:bot) {
    make_bot(Cinch::Plugins::TyrantUpdate) { |c|
      self.loggers.stub('debug') { nil }
    }
  }

  it 'makes a test bot' do
    expect(bot).to be_a Cinch::Bot
  end
end
