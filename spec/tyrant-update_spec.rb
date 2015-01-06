require_relative 'test-common'

require 'cinch/plugins/tyrant-update'

describe Cinch::Plugins::TyrantUpdate do
  include Cinch::Test

  let(:bot) {
    make_bot(Cinch::Plugins::TyrantUpdate) { |c|
      self.loggers.each { |l| l.level = :fatal }
    }
  }

  it 'makes a test bot' do
    expect(bot).to be_a Cinch::Bot
  end
end
