def get_chunk(chunk_id)
  REDIS.hgetall("chunks:#{chunk_id}")
end

def generate_chunk_key
  rand(1e25)
end

def get_chunk_key(chunk_id, client_addr)
  chunk = get_chunk(chunk_id)
  if (chunk != {}) && chunk["workers"].split(',').index(client_addr)
    chunk["key"]
  else
    nil
  end
end

# NOT threadsafe; it's totally possible that workers will get assigned to
# multiple chunks, which will result in failures. But the system is
# designed to tolerate that scenario; besides, clients can be multi-threaded.
def get_chunk_workers(foreman_addr, num_chunks)
  workers = get_available_workers
  workers.delete(foreman_addr) # Don't include foreman
  workers.take(num_chunks * 3) # Get 3 workers per chunk
end

# Threadsafe way to check if foreman has enough credits, and deduct if sufficient
def atomic_deduct_credits(foreman_addr, needed_credits)
  result = nil
  REDIS.lock(foreman_addr, LOCK_TIMEOUT, LOCK_MAX_ATTEMPTS)
  
  # Give the foreman credits if it hasn't registered before
  REDIS.hsetnx("clients:#{foreman_addr}", "credits", NUM_STARTING_CREDITS)
  available_credits = REDIS.hget("clients:#{foreman_addr}", "credits").to_i
  
  if available_credits >= needed_credits
    result = REDIS.hincrby("clients:#{foreman_addr}", "credits",  -needed_credits)
  end
               
  REDIS.unlock(foreman_addr)
  return result
end

# Assign workers to chunks and generate keys
def make_chunks(foreman_addr, workers)
  chunks = {}
  num_chunks = workers.length / 3
  num_chunks.times do
    chunk_id = REDIS.incr("chunks")
    chunk_workers = workers.pop(3)
    chunk_key = generate_chunk_key
    REDIS.hmset("chunks:#{chunk_id}", "foreman", foreman_addr,
                                      "workers", chunk_workers.join(','),
                                      "key", chunk_key)
    REDIS.expire("chunks:#{chunk_id}", DEFAULT_CHUNK_TTL)
    chunks[chunk_id] = chunk_workers.map{ |w| w + ':' + REDIS.hget("clients:#{w}", "port") } # Append workers' ports to address
  end
  chunks
end

# Threadsafe way of doing chunk deletion. Prevents foreman from trying to both
# get a chunk key and get a "refund" for it
def atomic_delete_chunk(chunk_id, foreman_addr, valid)
  result = nil
  REDIS.lock("chunks:#{chunk_id}", LOCK_TIMEOUT, LOCK_MAX_ATTEMPTS)
  
  chunk = get_chunk(chunk_id)
  
  # Check existence and validity before deletion
  if (chunk != {}) && (chunk["foreman"] == foreman_addr)
    REDIS.del("chunks:#{chunk_id}")
    if valid
      result = { :key => chunk["key"] }
      chunk["workers"].split(",").each do |worker|
        REDIS.hincrby("clients:#{worker}", "credits", 1)
        REDIS.hincrby("clients:#{worker}", "chunks_complete", 1)
      end
    else
      result = { :credits => REDIS.hincrby("clients:#{foreman_addr}", "credits", 3) }
    end
  end
  
  REDIS.unlock("chunks:#{chunk_id}")
  return result
end