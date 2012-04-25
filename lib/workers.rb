# Adds worker to the available pool by address, and adds or updates port and
# TTL. Can also be used for de-registering workers. Port and ttl must default
# to nil because routing code may naively call them with nil values, so the
# function must check for them anyway.
def add_worker(addr, port=nil, ttl=nil)
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

# Returns a list of available workers, conveniently taking advantage of Redis'
# sorted set data structure.
def get_available_workers
  REDIS.zrangebyscore("workers", Time.now.to_i, :inf).shuffle
end

# Returns all known info about a client from an address; throws UnknownClient
# if no record of the client exists
def get_client(addr)
  client = REDIS.hgetall("clients:#{addr}")
  raise UnknownClient if client == {}
  return client
end

# Generates a list of random addresses; includes localhost by default
def generate_addrs(n, localhost=true)
  addrs = Array.new(n).map do
    Array.new(4).map{rand(256)}.join('.')
  end
  addrs << '127.0.0.1' if localhost
end

# Adds the given list of addresses to the worker pool. Useful for testing.
def seed_db_with_workers(addrs)
  addrs.each do |addr|
    add_worker(addr)
  end
end