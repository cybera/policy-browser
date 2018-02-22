module Memcached
  mattr_accessor :memcached_client
  mattr_accessor :memcached_connection_string

  class << self
    def connect(hostname="memcached", port=11211)
      Memcached.memcached_connection_string = "#{hostname}:#{port}"
      Memcached.memcached_client = Dalli::Client.new(Memcached.memcached_connection_string, value_max_bytes: 16777216)
    end
  end

  def cache_get(key, &block)
    return yield if !self.memcached_client || !self.cache_active?

    begin
      value = self.memcached_client.get(key)
      if !value && block
        value = yield
        self.memcached_client.set(key, value)
      end
      value
    rescue Exception => e 
      # If something unexpected goes wrong with memcached, try to at least return the value
      puts e
      yield 
    end
  end

  def cache_delete(key)
    return if !self.memcached_client || !self.cache_active?

    begin
      self.memcached_client.delete(key)
    rescue Exception => e
      puts e
    end
  end

  def cache_active?
    begin
      !Memcached.memcached_client.stats[Memcached.memcached_connection_string].nil?
    rescue Exception => e
      puts e
    end
  end
end