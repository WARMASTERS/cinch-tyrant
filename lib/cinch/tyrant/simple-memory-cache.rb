require 'date'

# A simple in-memory cache
module Cinch; module Tyrant; class SimpleMemoryCache
  CacheItem = Struct.new(:data, :time)

  def initialize
    @cache = {}
  end

  # Returns [cache data, exception raised (if any)]
  def lookup(key, time, tolerate_exceptions: false)
    cached = @cache[key]

    # If there is cached data and it is in time, return it now.
    return [cached.data, nil] if cached && Time.now.to_i - cached.time < time

    # Do a lookup by yielding to provided block.
    begin
      result = yield
    rescue => e
      # Argh, exception!
      # If we can tolerate them and there is cached data, return it.
      # Otherwise, we must reraise.
      raise unless tolerate_exceptions && cached
      return [cached.data, e] if tolerate_exceptions
    end

    # Store the results
    @cache[key] = CacheItem.new(result, Time.now.to_i)
    [result, nil]
  end
end; end; end
