module Settings
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
    'myplayer' => {
      user_id: 123456,
      auth_token: '111111222222333333444444555555666666777777888888999999aaaaaabbbb',
      flash_code: 'ccccccddddddeeeeeeffffff00000011',
      faction_id: 78910002,
      faction_name: 'My Faction',
      platform: 'kg',
    }
  }
end
