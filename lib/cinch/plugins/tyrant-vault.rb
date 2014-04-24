require 'cinch'
require 'cinch/tyrant/cmd'
require 'tyrant'

module Cinch; module Plugins; class TyrantVault
  include Cinch::Plugin

  match(/vault/i, method: :vault)
  match(/revault/i, method: :revault)

  COMMANDS = [
    Cinch::Tyrant::Cmd.new('vault', 'vault', '', true,
      'Shows the current contents of the Tyrant "Core" vault.'
    ),
  ]

  def initialize(*args)
    super
    @vault = ['Orbo'] * 8
    @vault_time = 0
  end

  def vault(m)
    return unless is_friend?(m)

    if @vault_time < Time.now.to_i
      result = _revault
      m.reply('failed to update vault') unless result
    end

    time_left = format_time(@vault_time - Time.now.to_i)
    m.reply('[VAULT] ' + @vault.join(', ') + '. Available for ' + time_left)
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

    @vault = json['cards_for_sale'].map { |x|
      card = shared[:cards_by_id][x.to_i]
      card ? card.name : 'Unknown card ' + x
    }

    @vault_time = json['cards_for_sale_starting'].to_i + 3 * HOUR

    true
  end
end; end; end
