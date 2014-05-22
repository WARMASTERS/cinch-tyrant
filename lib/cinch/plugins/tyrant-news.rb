require 'cinch'
require 'cinch/plugins/tyrant-poll'
require 'cinch/tyrant/cmd'
require 'set'
require 'tyrant/faction'
require 'tyrant/war'

module Cinch; module Plugins; class TyrantNews < TyrantPoll
  include Cinch::Plugin

  timer 60, method: :check_all

  match(/news(.*)/i)

  COMMANDS = [
    Cinch::Tyrant::Cmd.new('war', 'news', '<on|off>',
      lambda { |m| is_officer?(m) },
      'Turns war monitor on/off. ' +
      'New wars are announced in channel every minute if enabled.'
    ),
  ]

  class MonitoredFaction < TyrantPoll::MonitoredFaction
    attr_accessor :monitor

    def initialize(*args)
      super
      @acked_wars = Set.new
      @pending_finished_wars = Set.new

      wars = @tyrant.make_request('getActiveFactionWars')['wars']
      wars.each { |id, _| @acked_wars.add(id) }
    end

    def poll_name; 'getActiveFactionWars'; end
    def poll_params; ''; end

    # Returns [[json of new wars], [json of finished wars]]
    def poll_result(json)
      current_wars = Set.new

      wars = json['wars']
      wars.each { |id, _| current_wars.add(id) }

      current_not_acked = current_wars - @acked_wars
      acked_not_current = @acked_wars - current_wars
      @acked_wars = current_wars
      new_wars = []
      current_not_acked.each { |id| new_wars.push(wars[id]) }
      acked_not_current.each { |id| @pending_finished_wars.add(id) }

      return [new_wars, []] if @pending_finished_wars.empty?

      finished_wars = []

      @pending_finished_wars.each { |war_id|
        json = @tyrant.make_request('getFactionWarInfo',
                                    "faction_war_id=#{war_id}")
        finished_wars << json if json['completed'].to_i == 1
      }

      # Could I move this up?
      # Don't really want to modify set while iterating over it.
      finished_wars.each { |war|
        @pending_finished_wars.delete(war['faction_war_id'])
      }

      [new_wars, finished_wars]
    end

    def format(war)
      @tyrant.format_wars([war])
    end
  end

  def monitored_faction
    MonitoredFaction
  end

  def notification_type
    :wars
  end

  def notify(faction, channels, wars)
    return if wars.nil?
    new_wars, finished_wars = wars
    finished_wars.reverse.each { |war|
      # Since we're using getFactionWarInfo, we don't get 'victory' anymore :(
      defense = war['defender_faction_id'].to_i == faction.faction_id
      our_score = defense ? war['defender_points'] : war['attacker_points']
      our_score = our_score.to_i
      their_score = defense ? war['attacker_points'] : war['defender_points']
      their_score = their_score.to_i
      we_win = our_score > their_score || defense && our_score == their_score

      prefix = we_win ? 'VICTORY!!!' : 'Defeat!!!'
      channels.each { |c|
        Channel(c).send("[WAR] #{prefix} #{faction.format(war)}")
      }
    }
    new_wars.each { |war|
      defense_war = war['defender_faction_id'].to_i == faction.faction_id
      prefix = defense_war ? 'ALARUM!!! DEFENSE WAR!!!' : 'WAR UP!!!'
      channels.each { |c|
        Channel(c).send("[WAR] #{prefix} #{faction.format(war)}")
      }
    }
  end
end; end; end
