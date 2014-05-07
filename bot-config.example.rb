require 'cinch/tyrant/faction'
require './settings'

# Array[String] with each string being a channel to join when bot starts.
# Keys can be specified too with '#channelname key'.
CHANNELS_TO_JOIN = [
  '#tyrant',
  '#hole',
  '#holelead',
  '#holecq',
]

# Nickname this bot should use.
BOT_NICK = 'cinch-tyrant'

# Array[String] with each string being a nick who is a "master" of the bot.
# Masters (when identified to their nick) always have full access to all
# bot functionality.
BOT_MASTERS = []

# Faction ID identifies the faction associated with the channel.
# It can be set regardless of membership in the faction.
# Examples of faction-specific output that do not depend on faction
# membership is conquest alerts and the !tiles command.
#
# player_f should only return a name of a player who is in the faction.
# It is used for all faction-specific functions that require membership.
# The faction ID tied to the player supercedes the faction set in this file
# except in !conquest)
#
# A valid player and positive faction ID are needed for faction war alerts and
# chat forwarding.
BOT_FACTIONS = [
  Cinch::Tyrant::Faction.new(
    1534002,
    '#hole',
    ['#holelead', '#holecq'],
    lambda { 'EvilSplinter' },
    {
      :conquest => '#holelead',
    },
  ),
]

# Array[PluginClass] of plugins the bot should load on startup.
# If desired, further plugins can be loaded at runtime with the PluginManagement
# plugin.
BOT_PLUGINS = [
  Cinch::Plugins::TyrantCard,
  Cinch::Plugins::TyrantFaction,
  Cinch::Plugins::TyrantFactionChat,
  Cinch::Plugins::TyrantNews,
  Cinch::Plugins::TyrantPlayer,
  Cinch::Plugins::TyrantRegister,
  Cinch::Plugins::TyrantWar,
]

# Hash[PluginClass => Hash[:option_name => option_value]] of configuration
# options for each plugin. The possible configuration values for each plugin
# are explained below.
BOT_PLUGIN_OPTIONS = {
  Cinch::Plugins::TyrantCard => {
    # Path to XML file cards.xml
    :xml_file => Settings::CARDS_XML,
  },
  Cinch::Plugins::TyrantConquestPoll => {
    # Name of player (in Settings::PLAYERS) who will poll the map.
    :poller => 'mypoller',
    # Name of channel to which reports should be sent.
    :report_channel => '#cinch-tyrant-conquest',
    # Hash[channel_name => Hash[:conquest_option => bool]] for conquest news
    # settings for specific channels.
    :channels => {
      '#example' => {
        :cset_feedback => false,
      },
    },
  },
  Cinch::Plugins::TyrantFaction => {
    # Name of player (in Settings::PLAYERS) who will look up faction data.
    # This player will be unable to remain in a faction, as the lookup process
    # involves leaving the current faction.
    :checker => 'mychecker',
    # Name of a file storing the Faction name => ID mapping.
    :yaml_file => Settings::FACTIONS_YAML,
  },
  Cinch::Plugins::TyrantFactionChat => {
    # Hash[channel_name => [bool, int]] indicating whether to poll for that
    # channel, and the poll interval in minutes. Defaults to [true, 1]
    :channels => {
      '#example' => [true, 30],
    },
  },
  Cinch::Plugins::TyrantNews => {
    # Hash[channel_name => [bool, int]] indicating whether to poll for that
    # channel, and the poll interval in minutes. Defaults to [true, 1]
    :channels => {
      '#example' => [true, 30],
    },
  },
  Cinch::Plugins::TyrantPlayer => {
    # Name of player (in Settings::PLAYERS) who will look up player data.
    :checker => 'mychecker',
  },
  Cinch::Plugins::TyrantRaids => {
    # Name of player (in Settings::PLAYERS) who will look up raid data.
    :checker => 'mychecker',
    # Path to XML file raids.xml
    :xml => Settings::RAIDS_XML,
  },
  Cinch::Plugins::TyrantRegister => {
    # URL of file containing registration instructions
    :helpfile => 'http://www.example.com/register.txt'
  },
  Cinch::Plugins::TyrantStats => {
    # String prepended to all stats URLs.
    :base_url => 'http://www.example.com/stats/?',
    # Hash[player_name => faction_abbreviation] indicating the faction
    # abbreviation for each player. This abbreviation appears in the URL and is
    # used to find the password file.
    :factions => {
      'myplayer' => 'fac',
    },
    # Directory containing passwords for each faction.
    # The password file is expected to be in this directory, named
    # (faction abbreviation).txt
    :password_dir => Settings::TYRANT_DIR + '/stats_passwords',
  },
  Cinch::Plugins::TyrantTargets => {
    # Hash[faction ID => [low, high]] indicating the target range to look for.
    :channels => {
      1000002 => [500, 500],
    },
  },
  Cinch::Plugins::TyrantTile => {
    # Name of player (in Settings::PLAYERS) who will look up tile data.
    :checker => 'mychecker',
  },
  Cinch::Plugins::TyrantVault => {
    # Name of player (in Settings::PLAYERS) who will look up vault data.
    :checker => 'mychecker',
  },
}
