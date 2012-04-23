def add_worker(addr, port, ttl)
  port ||= DEFAULT_PORT
  ttl ||= DEFAULT_WORKER_TTL
  expiry = Time.now.to_i + ttl.to_i

  result = REDIS.multi do 
    REDIS.zadd("workers", expiry, addr)
    REDIS.hmset("clients:#{addr}", "addr", addr, "port", port, "expiry", expiry)
    REDIS.hsetnx("clients:#{addr}", "credits", NUM_STARTING_CREDITS) # Only assign credits if unassigned
  end
  
  REDIS.hgetall("clients:#{addr}")
end

def get_available_workers
  # Shuffle returned workers to avoid bias based on TTL
  REDIS.zrangebyscore("workers", Time.now.to_i, :inf).shuffle
end

def get_client(addr)
  client = REDIS.hgetall("clients:#{addr}")
  return client if client != {}
end