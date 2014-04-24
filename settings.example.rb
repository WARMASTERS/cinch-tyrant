module Settings
  Player = Struct.new(
    'Player',
    :user_id, :auth_token, :flash_code, :faction_id, :faction_name, :type
  )

  TYRANT_VERSION = raise 'You must set a tyrant version'
  USER_AGENT = raise 'You must set a user agent'
  TYRANT_DIR = raise 'You must set a Tyrant directory'
  CACHE_DIR = "#{TYRANT_DIR}/cache"
  CLIENT_CODE_DIR = "#{TYRANT_DIR}/client_codes"
  CARDS_XML = "#{TYRANT_DIR}/xml/cards.xml"
  MISSIONS_XML = "#{TYRANT_DIR}/xml/missions.xml"
  RAIDS_XML = "#{TYRANT_DIR}/xml/raids.xml"
  FACTIONS_YAML = "#{TYRANT_DIR}/factions.yaml"

  PLAYERS = {
    'myplayer' => Player.new(
      123456,
      '111111222222333333444444555555666666777777888888999999aaaaaabbbb',
      'ccccccddddddeeeeeeffffff00000011',
      78910002,
      'My Faction',
      'kg'
    ),
  }
end
