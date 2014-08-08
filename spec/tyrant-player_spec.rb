require_relative 'test-common'

require 'cinch/plugins/tyrant-player'

describe Cinch::Plugins::TyrantPlayer do
  include Cinch::Test

  let(:bot) {
    make_bot(Cinch::Plugins::TyrantPlayer, {:checker => 'checker'}) { |c|
      self.loggers.stub('debug') { nil }
    }
  }

  before :each do
    @conn = FakeConnection.new
    @tyrant = Tyrants.get_fake('checker', @conn)
    expect(Tyrants).to receive(:get).with('checker').and_return(@tyrant)
  end

  it 'makes a test bot' do
    expect(bot).to be_a Cinch::Bot
  end

  describe '!player' do
    let(:message) { make_message(bot, '!player joecool', channel: '#test') }

    before :each do
      expect(Tyrant).to receive(:id_of_name).with('joecool').and_return(47)
    end

    it 'shows player not in faction' do
      expect(@tyrant).to receive(:player_info_by_id).with(47).and_return({
        'user_data' => {
          'user_id' => '47',
          'name' => 'joecool',
          'level' => '3',
        }
      })
      expect(get_replies_text(message)).to be == [
        'joecool: Level 3, Not in a faction'
      ]
    end

    it 'shows player with different Tyrant name' do
      expect(@tyrant).to receive(:player_info_by_id).with(47).and_return({
        'user_data' => {
          'user_id' => '47',
          'name' => 'mycoolname',
          'level' => '3',
        }
      })
      expect(get_replies_text(message)).to be == [
        'mycoolname (AKA joecool): Level 3, Not in a faction'
      ]
    end

    it 'shows player with a faction' do
      expect(@tyrant).to receive(:player_info_by_id).with(47).and_return({
        'user_data' => {
          'user_id' => '47',
          'name' => 'joecool',
          'level' => '3',
        },
        'faction_data' => {
          'faction_id' => '1001',
          'name' => 'My Pony Faction',
          'level' => '7',
          'rating' => '133',
          'wins' => '222',
          'losses' => '111',
          'permission_level' => '3',
          'loyalty' => '1001',
        }
      })
      expect(get_replies_text(message)).to be == [
        'joecool: Level 3, Leader of My Pony Faction, 1001 LP. 133 FP (Level 7), 222/111 W/L'
      ]
    end
  end

  # TODO: Spec for !player in my faction (stats)
  # TODO: Spec for !player with number name
  # TODO: Spec for !defense
end
