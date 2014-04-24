require 'cinch'
require 'cinch/tyrant/cmd'

module Cinch; module Plugins; class TyrantRegister
  include Cinch::Plugin

  match(/register(?:\s+(\w+))?/i, method: :register)
  match(/reload\s+users/i, method: :reload_users)

  COMMANDS = [
    Cinch::Tyrant::Cmd.new('register', 'register', '<kongname>', true,
      'Registers your nick for use with this bot.'
    ),
  ]

  def initialize(*args)
    super
    @helpfile = config[:helpfile]
  end

  def register(m, kong_name = nil)
    unless kong_name
      # If known user says !register, display help file.
      # If unknown user says !register, be silent.
      return unless is_friend?(m)
      m.reply(@helpfile) if @helpfile
      return
    end

    success, msg = Cinch::Tyrant::Auth::ask_to_register(m, kong_name)
    m.reply((success ? 'OK. ' : 'Failed. ') + msg, true) if msg
  end

  def reload_users(m)
    return unless m.user.master?
    Cinch::Tyrant::Auth::reload
    m.user.send('Reloaded')
  end
end; end; end
