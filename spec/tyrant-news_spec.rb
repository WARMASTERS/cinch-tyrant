require_relative 'test-common'

require 'cinch/plugins/tyrant-news'

describe Cinch::Plugins::TyrantNews do
  include Cinch::Test

  let(:bot) {
    make_bot(Cinch::Plugins::TyrantNews) { |c|
      self.loggers.stub('debug') { nil }
    }
  }

  before :each do
    @conn = FakeConnection.new
    @tyrant = Tyrants.get_fake('testplayer', @conn)
    expect(Tyrants).to receive(:get).with('testplayer').and_return(@tyrant)
    @conn.respond('getActiveFactionWars', nil, {'wars' => {}})
  end

  it 'makes a test bot' do
    expect(bot).to be_a Cinch::Bot
  end

  it 'informs the channel of a new offensive war' do
    @chan = FakeChannel.new
    bot.plugins[0].stub(:Channel) { |n| @chan }
    wars = { 'wars' => {
      '1' => {
        'faction_war_id' => '1',
        'name' => 'THE ENEMY',
        'attacker_faction_id' => '1000',
        'defender_faction_id' => '1001',
        'start_time' => Time.now.to_i.to_s,
        'duration' => '6',
        'atk_pts' => '0',
        'def_pts' => '0',
      },
    }}
    @conn.respond('getActiveFactionWars', nil, wars)
    bot.plugins[0].get_timers[0].fire!

    expect(@chan.messages.shift).to be =~
      /^.*WAR UP!!!\S*\s*1 - faction 1000 vs THE ENEMY 0-0 \(\+0\) \d\d:\d\d:\d\d left/
    expect(@chan.messages).to be == []
  end

  context 'when offensive war has ended' do
    before :each do
      @chan = FakeChannel.new
      @time = 0

      Time::stub(:now) { Time.at(@time) }

      bot.plugins[0].stub(:Channel) { |n| @chan }
      @war = {
        'faction_war_id' => '1',
        'name' => 'THE ENEMY',
        'attacker_faction_id' => '1000',
        'defender_faction_id' => '1001',
        'start_time' => Time.now.to_i.to_s,
        'duration' => '6',
        'attacker_points' => '0',
        'defender_points' => '0',
      }
      wars = { 'wars' => {
        '1' => @war,
      }}
      @conn.respond('getActiveFactionWars', nil, wars)
      bot.plugins[0].get_timers[0].fire!

      @chan.messages.clear

      # 6 hours and 1 second pass!
      @time += 6 * HOUR + 1

      @conn.respond('getActiveFactionWars', nil, {'wars' => []})
      @war['completed'] = 1
    end

    it 'reports victory' do
      @war.merge!({
        'attacker_points' => '1',
        'attacker_rating_change' => '5',
        'defender_rating_change' => '-1',
      })
      # The victory member only appears in getOldFactionWars, NOT getFactionWarInfo
      @conn.respond('getFactionWarInfo', "faction_war_id=1", @war)
      bot.plugins[0].get_timers[0].fire!
      expect(@chan.messages.shift).to be =~
        /^.*VICTORY!!!\S*\s*1 - faction 1000 vs THE ENEMY 1-0 \(\+1\) 0d 00:00:\d\d ago, \+5 FP/
      expect(@chan.messages).to be == []
    end

    it 'reports defeat' do
      @war.merge!({
        'defender_points' => '1',
        'attacker_rating_change' => '-1',
        'defender_rating_change' => '5',
      })
      # The victory member only appears in getOldFactionWars, NOT getFactionWarInfo
      @conn.respond('getFactionWarInfo', "faction_war_id=1", @war)
      bot.plugins[0].get_timers[0].fire!
      expect(@chan.messages.shift).to be =~
        /^.*Defeat!!!\S*\s*1 - faction 1000 vs THE ENEMY 0-1 \(\-1\) 0d 00:00:\d\d ago, -1 FP/
      expect(@chan.messages).to be == []
    end

  end

  # TODO: !news (on|off)
end
