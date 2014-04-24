require 'cinch'
require 'tyrant'
require 'tyrant/rivals'

module Cinch; module Plugins; class TyrantDeclare
  include Cinch::Plugin

  match(/declare\s+(\S.*)/i, method: :declare)

  def declare(m, target)
    return unless m.user.master?

    channel = BOT_CHANNELS[m.channel.name]
    user = channel.player
    tyrant = Tyrants.get(user)
    early_declare_ok = false

    if target[0..11] == '--yes-really'
      target = target[12..-1].strip
      early_declare_ok = true
    end

    rivals = tyrant.make_request('getFactionRivals', 'name=' + target)['rivals']

    if rivals.size == 0
      m.reply('No, there is nobody with that name')
      return
    end
    if rivals.size > 1
      m.reply('No, that is ambiguous, ' + rivals.size.to_s)
      return
    end

    rival = rivals[0]

    if rival['infamy_gain'].to_i != 0
      m.reply('No, that would get us infamy')
      return
    end

    rating_time = rival['less_rating_time'].to_i
    too_early = ::Tyrant.decreased_fp(rating_time)
    if too_early && !early_declare_ok
      m.reply('Are you sure? That would give reduced FP')
      return
    end

    p = "target_faction_id=#{rival['faction_id']}&infamy_gain=0"
    json = tyrant.make_request('declareFactionWar', p)
    m.reply(json['result'])
    warn(json.to_s) if !json['result']
  end
end; end; end
