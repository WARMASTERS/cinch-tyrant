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
      expect(@factions).to receive(:get_first).with('testfaction').and_return(9001)
    end

    let(:message) { make_message(bot, '!faction testfaction', channel: '#test') }

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
  end

  # TODO: !faction repeat wrong names specs
  # TODO: !faction flags specs
  # TODO: !factionid specs
  # TODO: !link specs
end
