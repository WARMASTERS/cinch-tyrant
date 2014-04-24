module Cinch; module Tyrant; class Faction
  attr_reader :id, :main_channel, :other_channels

  def initialize(id, main_channel, other_channels,
                 player_f, channel_map)
    @id = id
    @main_channel = main_channel
    @other_channels = other_channels
    @player_function = player_f
    @channel_map = channel_map
  end

  def channels
    [@main_channel] + @other_channels
  end

  def player
    @player_function.call
  end

  def channel_for(sym)
    @channel_map[sym] || @main_channel
  end

end; end; end
