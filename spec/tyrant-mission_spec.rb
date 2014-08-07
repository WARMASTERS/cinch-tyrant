require_relative 'test-common'

require 'cinch/plugins/tyrant-mission'

describe Cinch::Plugins::TyrantMission do
  include Cinch::Test

  let(:bot) {
    opts = {
      :xml_file => xml_file,
      :max_matches => 2,
    }
    make_bot(Cinch::Plugins::TyrantMission, opts) { |c|
      self.loggers.stub('debug') { nil }
    }
  }

  let(:xml_file) { 'blahblah.xml' }

  it 'makes a test bot' do
    Cinch::Plugins::TyrantMission.stub(:parse_missions).and_return([])
    expect(bot).to be_a Cinch::Bot
  end

  describe '::parse_missions' do
    let(:xml_content) { <<-MISSION
        <mission>
          <name>My mission</name>
          <commander>1001</commander>
          <deck>
            <card>1</card><card>2</card>
          </deck>
        </mission>'
      MISSION
    }

    it 'loads missions from XML' do
      expect(IO).to receive(:read).with(xml_file).and_return(xml_content)
      missions = Cinch::Plugins::TyrantMission.parse_missions(xml_file)
      expect(missions.size).to be == 1
      m = missions.first
      expect(m.name).to be == 'My mission'
      expect(m.commander).to be == 1001
      expect(m.cards).to be == { 1 => 1, 2 => 1 }
    end
  end

  describe '!mission' do
    let(:card1) { FakeCard.new(1, 'My First Card Story') }
    let(:commander1) { FakeCard.new(1001, 'Commander 1', :commander) }

    before :each do
      m = Cinch::Plugins::TyrantMission::Mission
      missions = [
        m.new('Mission 1', 1001, {999 => 1, 1 => 1}),
        m.new('Mission 2', 1002, {999 => 1, 2 => 1}),
        m.new('Mission 3', 1003, {999 => 1, 3 => 1}),
      ]
      missions.each { |m| m.cards.default = 0 }
      Cinch::Plugins::TyrantMission.stub(:parse_missions).and_return(missions)
      bot.plugins[0].stub(:shared).and_return({
        :cards_by_id => {
          1 => card1,
          999 => FakeCard.new(999, 'wat'),
          1001 => commander1,
        },
      })
    end

    it 'filters by cards' do
      message = make_message(bot, '!mission [1]')
      expect(get_replies_text(message)).to be == ['1 matches: Mission 1']
    end

    it 'filters by commander' do
      message = make_message(bot, '!mission [1001]')
      expect(get_replies_text(message)).to be == ['1 matches: Mission 1']
    end

    it 'complains if there are too many' do
      message = make_message(bot, '!mission [999]')
      expect(get_replies_text(message)).to be == [
        '3 matches: Maybe you should narrow down a bit more.'
      ]
    end
  end
end
