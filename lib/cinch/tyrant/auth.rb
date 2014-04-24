require 'cinch'
require 'securerandom'
require 'set'
require 'tyrant/player'
require 'yaml'

module Cinch; module Tyrant; class Auth
  class Faction
    attr_reader :nicks
    attr_reader :known_ids

    def initialize
      # nick => User
      @nicks = {}
      # Set[user_id]
      @known_ids = Set.new
    end
  end

  User = Struct.new(:user_id, :level)

  def self.load_file(filename)
    return nil unless File.exist?(filename)
    YAML.load_file(filename)
  end

  def self.save_file(hash, filename)
    File.open(filename, 'w') { |f|
      f.puts(YAML.dump(hash))
    }
  end

  # faction id => Faction
  FACTIONS = load_file('auth_factions.yaml') || {}
  FACTIONS.default_proc = proc { |h, k| h[k] = Faction.new }

  PENDING = {}

  def self.has_permission?(m, permission)
    nick = m.user.nick.downcase
    faction_id = BOT_CHANNELS[m.channel.name].id

    return false unless FACTIONS.has_key?(faction_id)
    return false unless FACTIONS[faction_id].nicks.has_key?(nick)

    unless m.user.authed?
      # if they aren't authed, refresh them to see if they've recently authed.
      m.user.refresh
      # still not authed
      return false unless m.user.authed?
    end

    FACTIONS[faction_id].nicks[nick].level >= permission
  end

  def self.ask_to_register(m, kong_name)
    return [false, nil] unless m.channel.voice_or_higher?(m.user)

    nick = m.user.nick.downcase

    faction_id = BOT_CHANNELS[m.channel.name].id

    unless m.user.authed?
      # if they aren't authed, refresh them to see if they've recently authed.
      m.user.refresh
      # still not authed
      return [false, nil] unless m.user.authed?
    end

    # Are they actually a Kong player?
    user_id = ::Tyrant.get_id_of_name(kong_name)
    return [false, 'No such player'] unless user_id

    if FACTIONS[faction_id].known_ids.include?(user_id)
      # Find what user it is? NAH
      return [false, 'User is already registered']
    end

    if FACTIONS[faction_id].nicks.has_key?(nick)
      return [false, 'You are already registered']
    end

    code = SecureRandom.hex
    PENDING[user_id] = [nick, code]

    return [true, 'Paste the following into faction chat: ' +
            "#{BOT_NICK} confirm #{nick} #{code}"]
  end

  DEFAULT_PERMISSIONS = [-1, 3, 7, 9, 5]

  def self.confirm_register(faction_id, user_id, nick, level, code)
    nick = nick.downcase
    return false unless PENDING[user_id] && PENDING[user_id][0] == nick

    return false unless code == PENDING[user_id][1]

    add_user(faction_id, user_id, nick, level)
    true
  end

  def self.add_user(faction_id, user_id, nick, level)
    PENDING.delete(user_id)
    FACTIONS[faction_id].known_ids.add(user_id)
    FACTIONS[faction_id].nicks[nick] = User.new(user_id, level)
    save
  end

  def self.reload
    FACTIONS.replace(load_file('auth_factions.yaml'))
  end

  def self.save
    save_file(FACTIONS, 'auth_factions.yaml')
  end
end; end; end

def is_friend?(m)
  Cinch::Tyrant::Auth::has_permission?(m, 1) || m.user.master?
end

def is_member?(m)
  Cinch::Tyrant::Auth::has_permission?(m, 3) || m.user.master?
end

def is_warmaster?(m)
  Cinch::Tyrant::Auth::has_permission?(m, 5) || m.user.master?
end

def is_officer?(m)
  Cinch::Tyrant::Auth::has_permission?(m, 7) || m.user.master?
end

def is_superofficer?(m)
  Cinch::Tyrant::Auth::has_permission?(m, 8) || m.user.master?
end

module Cinch
  class User
    def master?
      return false unless BOT_MASTERS.include?(name)
      refresh
      BOT_MASTERS.include?(authname)
    end
  end

  class Channel
    def owner?(user)
      owners.include?(user)
    end

    def admin_or_higher?(user)
      admins.include?(user) || owner?(user)
    end

    def op_or_higher?(user)
      opped?(user) || admin_or_higher?(user)
    end

    def half_op_or_higher?(user)
      half_opped?(user) || op_or_higher?(user)
    end

    def voice_or_higher?(user)
      voiced?(user) || half_op_or_higher?(user)
    end
  end
end
