def get_workers(n=nil)
  # Shuffle returned workers to avoid bias based on TTL
  workers = REDIS.zrangebyscore("workers", Time.now.to_i, :inf).shuffle
  
  # Only return n items if they're asked for
  n ? workers.take(n) : workers
end

def generate_chunk_key
  rand(1e25)
end