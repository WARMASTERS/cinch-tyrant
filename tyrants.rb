require 'tyrant/player'

require_relative './settings'

# This stuff is responsible for initing Tyrant objects
class Tyrants
  @@cache = {}
  @@kong_done = false

  def self.get(name)
    if !@@kong_done
      Tyrant.kong_connection =
        Connection.new('www.kongregate.com', Settings::CACHE_DIR)
      Tyrant.kong_user_agent = Settings::USER_AGENT
      @@kong_done = true
    end

    return @@cache[name] if @@cache[name]

    p = Settings::PLAYERS[name]
    raise 'No tyrant player ' + name unless p
    platform = p[:platform]
    conn = Connection.new("#{platform}.tyrantonline.com", Settings::CACHE_DIR)
    @@cache[name] ||= Tyrant.new(
      connection: conn,
      tyrant_version: Settings::TYRANT_VERSION,
      user_agent: Settings::USER_AGENT,
      name: name,
      client_code_dir: Settings::CLIENT_CODE_DIR,
      **p
    )
  end
end
