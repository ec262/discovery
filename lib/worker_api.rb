def add_worker(addr, port, ttl)
  expiry = Time.now.to_i + ttl.to_i

  result = REDIS.multi do 
    REDIS.zadd("workers", expiry, addr)
    REDIS.hset("clients:#{addr}", "port", port)
    REDIS.hset("clients:#{addr}", "expiry", expiry) # Only used for testing
    # Only give the worker credits if they haven't registered before
    REDIS.hsetnx("clients:#{addr}", "credits", NUM_STARTING_CREDITS)
  end
end