require_relative 'test-common'

require 'digest/sha1'

require 'cinch/plugins/tyrant-stats'

describe Cinch::Plugins::TyrantStats do
  include Cinch::Test

  let(:bot) {
    opts = {
      :base_url => 'http://localhost/stats.php?',
      :factions => {
        'testplayer' => 'somefaction',
      },
      :password_dir => '/tmp/tyrant/stats_passwords',
    }
    make_bot(Cinch::Plugins::TyrantStats, opts) { |c|
      self.loggers.stub('debug') { nil }
    }
  }

  it 'makes a test bot' do
    expect(bot).to be_a Cinch::Bot
  end

  let(:message) { make_message(bot, '!stats', channel: '#test') }

  it 'shows stats link to user' do
    message.user.stub(:signed_on_at).and_return(0)
    expect(IO).to receive(:read).with('/tmp/tyrant/stats_passwords/somefaction.txt').and_return('seekrit')
    password = Digest::SHA1.hexdigest('test$seekrit')
    replies = get_replies_text(message)
    expect(replies).to be == [
      'http://localhost/stats.php?faction=somefaction&username=test&password=' + password
    ]
  end

  it 'denies just-logged-in user' do
    message.user.stub(:signed_on_at).and_return(Time.now.to_i)
    replies = get_replies_text(message)
    expect(replies).to be == [
      'test: STAY A WHILE AND LISTEN! It is very rude to ask for !stats right after signing on.',
      'http://localhost/stats.php?faction=somefaction&username=stayawhile&password=andlisten',
    ]
  end
end
