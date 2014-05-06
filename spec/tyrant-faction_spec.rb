require_relative 'test-common'

require 'cinch/plugins/tyrant-faction'

describe Cinch::Plugins::TyrantFaction do
  include Cinch::Test

  let(:bot) {
    opts = {:checker => 'checker', :yaml_file => 'lolz'}
    make_bot(Cinch::Plugins::TyrantFaction, opts) { |c|
      self.loggers.stub('debug') { nil }
    }
  }

  it 'makes a test bot' do
    expect(bot).to be_a Cinch::Bot
  end

  def make_faction(opts = {})
    {
      'faction_id' => '9001',
      'name' => 'testfaction',
      'num_members' => '4',
      'activity_level' => '50',
      'level' => '19',
      'rating' => '700',
      'wins' => '1337',
      'losses' => '7331',
      'num_territories' => '2',
      'conquest_rating' => '5',
      'result' => true,
    }.merge(opts)
  end

  describe '!faction' do
    before :each do
      @conn = FakeConnection.new
      @tyrant = Tyrants.get_fake('checker', @conn)
      expect(Tyrants).to receive(:get).with('checker').and_return(@tyrant)

      @factions = {}

      allow(File).to receive(:exist?).with('/dev/null/1').and_return(false)

      # Pretend the yaml file exists, then load a dummy object from it.
      expect(File).to receive(:exist?).with('lolz').and_return(true)
      expect(YAML).to receive(:load_file).with('lolz').and_return(@factions)
      expect(@factions).to receive(:get_first).with(faction_name).and_return(faction_id)
    end

    let(:message) { make_message(bot, '!faction testfaction', channel: '#test') }
    let(:faction_name) { 'testfaction' }
    let(:faction_id) { 9001 }

    it 'shows faction info' do
      @conn.respond('applyToFaction', 'faction_id=9001', make_faction)
      @conn.respond('leaveFaction', '', { 'result' => true })
      expect(get_replies_text(message)).to be == [
        'testfaction: 4 members (50% active), Level 19, 700 FP, 1337/7331 W/L, 5 CR, 2 tiles'
      ]
    end

    it 'reports if faction could not be joined' do
      @conn.respond('applyToFaction', 'faction_id=9001', {
        'result' => false,
      })
      # TODO: Hmm, maybe we could remove this leaveFaction
      @conn.respond('leaveFaction', '', { 'result' => false })
      expect(get_replies_text(message)).to be == [
        'Failed to get info on "testfaction". This probably means they disbanded.'
      ]
    end

    describe '!faction -c on other faction' do
      let(:message) { make_message(bot, '!faction -c testfaction', channel: '#test') }

      before :each do
        @conn.respond('applyToFaction', 'faction_id=9001', make_faction({
          'conquest_attacks' => 4,
          'conquest_attack_recharge' => Time.now.to_i - 3600,
        }))
        @conn.respond('leaveFaction', '', { 'result' => true })
      end

      context 'with a master' do
        before :each do
          message.user.stub(:master?).and_return(true)
        end

        it 'shows conquest attacks' do
          expect(get_replies_text(message)).to be == [
            'testfaction: 4 members (50% active), Level 19, 700 FP, 1337/7331 W/L, 5 CR, 2 tiles',
            '4/6 attacks - next in 03:00:00'
          ]
        end
      end

      context 'with a normal user' do
        before :each do
          message.user.stub(:master?).and_return(false)
        end

        it 'does not show conquest attacks' do
          expect(get_replies_text(message)).to be == [
            'testfaction: 4 members (50% active), Level 19, 700 FP, 1337/7331 W/L, 5 CR, 2 tiles',
          ]
        end
      end
    end

    describe '!faction -c on own faction' do
      let(:message) { make_message(bot, '!faction -c myfaction', channel: '#test') }
      let(:faction_name) { 'myfaction' }
      let(:faction_id) { 1000 }

      before :each do
        @conn.respond('applyToFaction', 'faction_id=1000', make_faction({
          'faction_id' => '1000',
          'name' => 'myfaction',
          'conquest_attacks' => 4,
          'conquest_attack_recharge' => Time.now.to_i - 3600,
        }))
        @conn.respond('leaveFaction', '', { 'result' => true })
      end

      context 'with a master' do
        before :each do
          message.user.stub(:master?).and_return(true)
        end

        it 'shows conquest attacks' do
          expect(get_replies_text(message)).to be == [
            'myfaction: 4 members (50% active), Level 19, 700 FP, 1337/7331 W/L, 5 CR, 2 tiles',
            '4/6 attacks - next in 03:00:00'
          ]
        end
      end

      context 'with a normal user' do
        before :each do
          message.user.stub(:master?).and_return(false)
        end

        it 'shows conquest attacks' do
          expect(get_replies_text(message)).to be == [
            'myfaction: 4 members (50% active), Level 19, 700 FP, 1337/7331 W/L, 5 CR, 2 tiles',
            '4/6 attacks - next in 03:00:00'
          ]
        end
      end
    end
  end

  # TODO: !faction -m and !faction -f specs

  # TODO: !faction repeat wrong names specs
  # TODO: !factionid specs
  # TODO: !link specs
end
