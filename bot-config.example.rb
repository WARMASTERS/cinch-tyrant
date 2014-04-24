require 'cinch/tyrant/faction'

CHANNELS_TO_JOIN = [
  '#tyrant',
  '#hole',
  '#holelead',
  '#holecq',
]

BOT_NICK = 'cinch-tyrant'
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
