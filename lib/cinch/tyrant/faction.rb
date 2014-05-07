module Cinch; module Tyrant; class Faction
  attr_reader :id, :main_channel, :other_channels

  def initialize(
    id: -1,
    main_channel:,
    other_channels: [],
    player: nil,
    channel_map: {}
  )
    @id = id
    @main_channel = main_channel
    @other_channels = other_channels
    @player = player
    @channel_map = channel_map
  end

  def channels
    [@main_channel] + @other_channels
  end

  def player
    @player.respond_to?(:call) ? @player.call : @player
  end

  def channel_for(sym)
    @channel_map[sym] || @main_channel
  end

end; end; end
