require 'cinch'
require 'cinch/tyrant/cmd'
require 'digest/sha1'
require 'tyrant'

module Cinch; module Plugins; class TyrantStats
  include Cinch::Plugin

  WAIT_TIME = 10 * MINUTE

  match(/stats/i, method: :stats)

  HALP = 'Gives the link to the stats page with player and war data. ' +
         'The link is unique to you and must NEVER be shared. ' +
         'The password changes every week.'

  COMMANDS = [
    Cinch::Tyrant::Cmd.new('player', 'stats', '',
      lambda { |m| is_member?(m) },
      HALP
    ),
    Cinch::Tyrant::Cmd.new('war', 'stats', '',
      lambda { |m| is_member?(m) },
      HALP
    ),
  ]

  def stats(m)
    return unless is_member?(m)

    user = BOT_CHANNELS[m.channel.name].player
    targ = (config[:factions] || {})[user]
    return unless targ

    password_filename = "#{config[:password_dir]}/#{targ}.txt"

    base = config[:base_url]

    if m.user.signed_on_at.to_i + WAIT_TIME > Time.now.to_i
      m.reply('STAY A WHILE AND LISTEN! ' +
              'It is very rude to ask for !stats right after signing on.', true)
      m.user.notice("#{base}faction=#{targ}&username=stayawhile&password=andlisten")
      return
    end

    user = m.user.name.downcase
    pass = IO.read(password_filename)
    pass = Digest::SHA1.hexdigest(user + '$' + pass)

    m.user.notice("#{base}faction=#{targ}&username=#{user}&password=#{pass}")
  end
end; end; end
