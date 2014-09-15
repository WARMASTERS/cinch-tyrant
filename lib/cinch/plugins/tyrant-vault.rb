require 'cinch'
require 'cinch/tyrant/cmd'
require 'tyrant'
require 'tyrant/time'

module Cinch; module Plugins; class TyrantVault
  include Cinch::Plugin

  match(/vault/i, method: :vault)
  match(/revault/i, method: :revault)

  COMMANDS = [
    Cinch::Tyrant::Cmd.new('vault', 'vault', '', true,
      'Shows the current contents of the Tyrant "Core" vault.'
    ),
  ]

  VAULT_PERIOD = 3 * ::Tyrant::Time::HOUR
  # Delay this number of seconds after a new vault before alerting on it
  VAULT_ALERT_DELAY = 2

  def initialize(*args)
    super
    _revault
    schedule_alert
  end

  def vault(m)
    return unless is_friend?(m)

    if @vault_time < Time.now.to_i
      result = _revault
      m.reply('failed to update vault') unless result
    end

    time_left = ::Tyrant::Time::format_time(@vault_time - Time.now.to_i)
    m.reply("[VAULT] #{vault_names.join(', ')}. Available for #{time_left}")
  end

  def revault(m)
    return unless m.user.master?

    result = _revault
    m.reply('failed to update vault') unless result
  end

  def _revault
    json = Tyrants.get(config[:checker]).make_request('getMarketInfo')

    if !json['cards_for_sale'] || !json['cards_for_sale_starting']
      return false
    end

    @vault_ids = json['cards_for_sale']
    @vault_names = nil
    @vault_time = json['cards_for_sale_starting'].to_i + VAULT_PERIOD

    true
  end

  def vault_names
    @vault_names ||= @vault_ids.map { |x|
      card = shared[:cards_by_id] && shared[:cards_by_id][x.to_i]
      card ? card.name : 'Unknown card ' + x
    }
  end

  def schedule_alert
    return unless config[:alert_channels]
    time_left = @vault_time - Time.now.to_i
    time = time_left + VAULT_ALERT_DELAY
    Timer(time, {:shots => 1, :start_automatically => false, :method => :alert})
  end

  def alert
    _revault
    channels = config[:alert_channels]
    msg = '[NEW VAULT] ' + vault_names.join(', ')
    channels.each { |c| Channel(c).send(msg) }
    schedule_alert
  end
end; end; end
