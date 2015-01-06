require_relative 'test-common'

require 'cinch/plugins/tyrant-vault'

describe Cinch::Plugins::TyrantVault do
  include Cinch::Test

  let(:bot) {
    make_bot(Cinch::Plugins::TyrantVault, {:checker => 'testplayer'}) { |c|
      self.loggers.each { |l| l.level = :fatal }
    }
  }
  let(:plugin) { bot.plugins.first }

  before :each do
    @conn = FakeConnection.new
    @tyrant = Tyrants.get_fake('testplayer', @conn)
    set_up_vault
  end

  def set_up_vault
    expect(Tyrants).to receive(:get).with('testplayer').and_return(@tyrant)
    @conn.respond('getMarketInfo', '', {
      'cards_for_sale' => ['1', '2'],
      'cards_for_sale_starting' => Time.now.to_i,
    })
  end

  def set_up_cards
    allow(plugin).to receive(:shared).and_return({:cards_by_id => {
      1 => FakeCard.new(1, 'My first card'),
      2 => FakeCard.new(2, 'Another awesome card'),
    }})
  end

  it 'makes a test bot' do
    expect(bot).to be_a Cinch::Bot
  end

  describe '!vault' do
    let(:message) { make_message(bot, '!vault', channel: '#test') }

    it 'shows vault cards' do
      set_up_cards
      replies = get_replies_text(message)
      expect(replies.shift).to be =~
        /^\[VAULT\] My first card, Another awesome card\. Available for \d\d:\d\d:\d\d$/
      expect(replies).to be == []
    end
  end

  # TODO: revault?!

  describe 'vault channel alerts' do
    it 'fires' do
      allow(plugin).to receive(:config).and_return({
        :checker => 'testplayer',
        :alert_channels => ['#vaultalerts'],
      })
      set_up_cards
      set_up_vault
      chan = FakeChannel.new
      expect(plugin).to receive(:Channel).with('#vaultalerts').and_return(chan)
      plugin.alert
      expect(chan.messages.shift).to be =~
        /^\[NEW VAULT\] My first card, Another awesome card$/
      expect(chan.messages).to be == []
    end
  end

  describe 'vault card subscriptions' do
    it 'alerts the subscribers' do
      allow(plugin).to receive(:config).and_return({
        :checker => 'testplayer',
        :subscriptions => {'Another awesome card' => ['iwanttoknow']}
      })
      set_up_cards
      set_up_vault
      user = FakeChannel.new
      expect(plugin).to receive(:User).with('iwanttoknow').and_return(user)
      expect(user).to receive(:authed?).and_return(true)
      plugin.alert
      expect(user.messages).to be == [
        'Hey iwanttoknow, guess what? Another awesome card is in the vault!!!'
      ]
    end

    it 'does not alert an unauthed person' do
      allow(plugin).to receive(:config).and_return({
        :checker => 'testplayer',
        :subscriptions => {'Another awesome card' => ['iwanttoknow']}
      })
      set_up_cards
      set_up_vault
      user = FakeChannel.new
      expect(plugin).to receive(:User).with('iwanttoknow').and_return(user)
      expect(user).to receive(:authed?).and_return(false)
      plugin.alert
      expect(user.messages).to be == []
    end
  end
end
