require 'cinch'

require 'cinch/tyrant/auth'
require 'cinch/plugins/plugin-management'
require 'cinch/plugins/tyrant-card'
require 'cinch/plugins/tyrant-conquest'
require 'cinch/plugins/tyrant-conquest-commands'
require 'cinch/plugins/tyrant-conquest-poll'
require 'cinch/plugins/tyrant-declare'
require 'cinch/plugins/tyrant-faction'
require 'cinch/plugins/tyrant-faction-chat'
require 'cinch/plugins/tyrant-history'
require 'cinch/plugins/tyrant-mission'
require 'cinch/plugins/tyrant-news'
require 'cinch/plugins/tyrant-player'
require 'cinch/plugins/tyrant-raids'
require 'cinch/plugins/tyrant-register'
require 'cinch/plugins/tyrant-say'
require 'cinch/plugins/tyrant-stats'
require 'cinch/plugins/tyrant-targets'
require 'cinch/plugins/tyrant-tile'
require 'cinch/plugins/tyrant-vault'
require 'cinch/plugins/tyrant-war'
require 'tyrant/cards'

require './bot-config'
require './tyrants'

BOT_CHANNELS = {}
BOT_IDS = {}

BOT_FACTIONS.each { |f|
  f.channels.each { |c| BOT_CHANNELS[c] = f }
  BOT_IDS[f.id] = f if f.id >= 0
}

bot = Cinch::Bot.new do
  configure do |c|
    c.server = 'irc.mibbit.net'
    c.nick = BOT_NICK
    c.channels = CHANNELS_TO_JOIN
    c.plugins.plugins = BOT_PLUGINS
    c.plugins.options = BOT_PLUGIN_OPTIONS

    by_id, by_name = Tyrant::Cards::parse_cards(Settings::CARDS_XML)
    c.shared[:cards_by_id] = by_id
    c.shared[:cards_by_name] = by_name
  end

  on :message, /^!listcommands$/i do |m|
    next unless is_friend?(m)

    commands = m.bot.config.plugins.plugins.map { |p|
      defined?(p::COMMANDS) ? p::COMMANDS : []
    }
    visible = commands.flatten.select { |c| c.visible?(m) }
    cmds = visible.map { |c| c.command }.uniq.join(', ')

    m.user.send("All commands: #{cmds}")
  end

  on :message, /^!help$/i do |m|
    next unless is_friend?(m)

    commands = m.bot.config.plugins.plugins.map { |p|
      defined?(p::COMMANDS) ? p::COMMANDS : []
    }
    visible = commands.flatten.select { |c| c.visible?(m) }
    cats = visible.map { |c| c.category }.uniq.sort.join(', ')

    m.user.send('!listcommands will list all commands ' +
                'but will not display explanations for each command.')
    m.user.send("For explanations, choose one of these categories: #{cats}")
    m.user.send('Use !help <category> to get help on that category.')
  end

  on :message, /^!help\s+(\w+)$/i do |m, cat|
    next unless is_friend?(m)

    commands = m.bot.config.plugins.plugins.map { |p|
      defined?(p::COMMANDS) ? p::COMMANDS : []
    }
    cmds = commands.flatten.select { |c| c.visible?(m) && c.category == cat }
    messages = cmds.map { |p| p.to_s }

    m.user.send(messages.join("\n"))
  end
end

bot.start
