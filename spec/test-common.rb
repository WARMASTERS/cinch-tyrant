require 'cinch'
require 'cinch/test'

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
      connection,
      'faketype', 'fakeversion', 'fakeagent', {}, #configs
      name, 1, 'flashcode', 'authtoken',
      1000, 'faction 1000',
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
    @responses = {}
  end

  REQ_REGEX = /\/api\.php\?user_id=\d+&message=(\w+)/

  def respond(message, params, response)
    @responses[message] = response
  end

  def request(url, params, configs)
    if match = REQ_REGEX.match(url)
      message = match[1]
    else
      raise "#{url} is not a valid request"
    end

    raise "unexpected message #{message}" unless @responses.has_key?(message)
    DeflatedResponse.new(JSON::dump(@responses[message]))
  end

  def cached_gzip_request(path, data, headers, key, delay)
    request(path, data, headers)
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

FakeCard = Struct.new(:id, :name) do
  def hash
    Tyrant::Cards::hash_of_id(self[:id])
  end
end
