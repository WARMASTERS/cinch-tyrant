require_relative 'test-common'

require 'cinch/plugins/tyrant-conquest-commands'

describe Cinch::Plugins::TyrantConquestCommands do
  include Cinch::Test

  let(:bot) {
    make_bot(Cinch::Plugins::TyrantConquestCommands) { |c|
      self.loggers.stub('debug') { nil }
    }
  }

  it 'makes a test bot' do
    expect(bot).to be_a Cinch::Bot
  end

  # TODO TyrantConquestCommands tests
end
