require 'cinch'
require 'tyrant'

module Cinch; module Plugins; class TyrantUpdate
  include Cinch::Plugin

  match(/log (\S+) (.+)/i, method: :log)
  match(/update (\S+) (.+)/i, method: :update)

  def log(m, player, path)
    return unless m.user.master?

    path = nil if path == '!nil'
    tyrant = Tyrants.get(player)
    tyrant.log_path = path
    m.reply(player + ' ' + tyrant.log_path)
  end

  def update(m, player, version)
    return unless m.user.master?

    Tyrants.get(player).tyrant_version = version
    m.reply(player + ' ' + version)
  end
end; end; end
