require 'cinch'
require 'cinch/test'
require 'rspec/mocks'

BOT_NICK = 'testbot'

# =================== TIMER SETUP ===================

FakeTimerInfo = Struct.new(:interval, :method)

class FakeTimer
  attr_reader :interval, :method
  def initialize(interval, method, &block)
    @interval = interval
    @method = method
    @block = block
  end

  def fire!
    @block.call
  end
end

module Cinch
  module Plugin
    module ClassMethods
      attr_reader :fake_timers
      def timer(interval, opts = {})
        @fake_timers ||= []
        @fake_timers << FakeTimerInfo.new(interval, opts[:method])
      end
    end

    def __register_timers
      # pass
    end

    def get_timers
      self.class.fake_timers.map { |t|
        FakeTimer.new(t.interval, t.method, &self.method(t.method))
      }
    end
  end
end

class FakeChannel
  attr_reader :messages
  def initialize
    @messages = []
  end
  def send(msg)
    @messages << msg
  end
end

# =================== PERMISSION LIST ===================

BOT_MASTERS = []

def is_friend?(m)
  true
end

def is_member?(m)
  true
end

def is_warmaster?(m)
  true
end

def is_officer?(m)
  true
end

# =================== CONVENIENCE ===================

def get_replies_text(message)
  get_replies(message).map(&:text)
end

# =================== BOT CHANNELS ===================

ChannelInfo = Struct.new(:player, :player_id, :faction_id, :main_channel) do
  alias :id :faction_id
  def channel_for(_)
    self[:main_channel]
  end

  def channels
    [self[:main_channel]]
  end
end

BOT_CHANNELS = {
  '#test' => ChannelInfo.new('testplayer', 1, 1000, '#test')
}
BOT_FACTIONS = BOT_CHANNELS.values
BOT_IDS = {
  1000 => BOT_CHANNELS['#test']
}

# =================== TYRANT CONNECTION ===================

class Tyrants
  def self.get_fake(name, connection)
    Tyrant.new(
      connection: connection,
      platform: 'faketype',
      tyrant_version: 'fakeversion',
      user_agent: 'fakeagent',
      name: name,
      user_id: 1,
      flash_code: 'flashcode',
      auth_token: 'authtoken',
      faction_id: 1000,
      faction_name: 'faction 1000',
      client_code_dir: '/dev/null'
    )
  end
end

class DeflatedResponse
  def initialize(response)
    @response = response
  end

  def inflate
    @response
  end

  def to_str
    @response
  end
end

class FakeConnection
  def initialize
    RSpec::Mocks::setup(self)
  end

  def respond(message, params, response)
    regex = req_regex(message)
    expected_params =
      if params && !params.empty?
        /^#{params}&flashcode=/
      elsif params
        # Params present but is blank string
        /^flashcode=/
      else
        # nil?!
        raise "No params specified for #{message}"
      end
    expect(self).to receive(:request).with(regex, expected_params, anything).and_return(DeflatedResponse.new(JSON::dump(response)))
  end

  def cached_gzip_request(path, data, headers, key, delay)
    self.request(path, data, headers)
  end

  private

  def req_regex(message)
    /\/api\.php\?user_id=\d+&message=#{message}/
  end
end

# =================== CONQUEST ===================

def make_tile(id, owner_id = nil, attacker_id = nil, cr: 1, x: 0, y: 0)
  t = {
    'system_id' => id,
    'rating' => cr,
    # These keys are always present even if tile is neutral and unattacked.
    'faction_id' => nil,
    'attacking_faction_id' => nil,
    'x' => x,
    'y' => y,
  }

  if owner_id
    t['faction_id'] = owner_id
    t['faction_name'] = "faction #{owner_id}"
  end

  if attacker_id
    t['attacking_faction_id'] = attacker_id
    t['attacking_faction_name'] = "faction #{attacker_id}"
  end

  t
end

# =================== CARDS ===================

FakeCard = Struct.new(:id, :name, :type) do
  def hash
    Tyrant::Cards::hash_of_id(self[:id])
  end
end
