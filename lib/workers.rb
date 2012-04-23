def add_worker(addr, port, ttl)
  expiry = Time.now.to_i + ttl.to_i

  result = REDIS.multi do 
    REDIS.zadd("workers", expiry, addr)
    REDIS.hset("clients:#{addr}", "addr", addr)
    REDIS.hset("clients:#{addr}", "port", port)
    REDIS.hset("clients:#{addr}", "expiry", expiry)
    # Only give the worker credits if they haven't registered before
    REDIS.hsetnx("clients:#{addr}", "credits", NUM_STARTING_CREDITS)
  end
  
  REDIS.hgetall("clients:#{addr}")
end

def get_all_workers
  # Shuffle returned workers to avoid bias based on TTL
  REDIS.zrangebyscore("workers", Time.now.to_i, :inf).shuffle
end

def get_client(addr)
  REDIS.hgetall("clients:#{addr}")
end