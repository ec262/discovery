# Returns everything known about a chunk
def get_chunk(chunk_id)
  REDIS.hgetall("chunks:#{chunk_id}")
end

# Generates a (theoretically) secure key for AES-128 encryption. 
def generate_chunk_key
  require 'openssl'
  require 'base64'
  Base64.encode64(OpenSSL::Cipher.new("aes-128-ecb").random_key)
end

# Returns the key for a chunk if the client is permitted to see it; otherwise
# raises an UnknownChunk exceptions
def get_chunk_key(chunk_id, client_addr)
  chunk = get_chunk(chunk_id)
  raise UnknownChunk unless (chunk != {}) && chunk["workers"].split(',').index(client_addr)
  { :key => chunk["key"] }
end

# Get as many workers as possible; ensure that the foreman is not in the list
# of workers; remove workers from the availability pool. Note that this is
# NOT threadsafe; it's totally possible that foreman will get "busy" workers,
# which could result in the chunk failing. Fortunately the the system is
# designed to tolerate that scenario (see docs)
def get_chunk_workers(foreman_addr, num_chunks_requested)
  num_workers = num_chunks_requested * WORKERS_PER_CHUNK
  workers = get_available_workers.reject{ |w| w == foreman_addr }.take(num_workers)
  workers.each do |worker|
    REDIS.zrem("workers", worker)
  end
end

# Threadsafe way to check if foreman has enough credits, and deduct if
# sufficient. Returns the number of credits left in foreman's account if
# successful; otherwise raises InsufficientCredits exception.
def atomic_deduct_credits(foreman_addr, needed_credits)
  # Lock the foreman's account
  REDIS.lock("clients:#{foreman_addr}", LOCK_TIMEOUT, LOCK_MAX_ATTEMPTS)
  
  # Give the foreman credits if it hasn't registered before
  REDIS.hsetnx("clients:#{foreman_addr}", "credits", NUM_STARTING_CREDITS)
  available_credits = REDIS.hget("clients:#{foreman_addr}", "credits").to_i
  
  if available_credits >= needed_credits
    REDIS.hincrby("clients:#{foreman_addr}", "credits",  -needed_credits)
  else
    raise InsufficientCredits.new(available_credits, needed_credits)
  end
ensure
  REDIS.unlock("clients:#{foreman_addr}")
end

# Assign workers to chunks and generate keys. Chunk IDs are generated by
# incrementing the "chunks" key in Redis; this ensures atomicity. Each credit
# then gets three workers assigned to it, along with a key which is stored
# in Redis but not returned.  Can raise InsufficientCredits exception from
# atomic_deduct_credits. Returns a hash of the form
# { "1" => ["worker1:port", "worker2:port", "worker3:port"],
#   "2" => ["worker4:port", ...], ...
# }
def make_chunks(foreman_addr, num_chunks_requested, workers=nil)
  # Get a list of workers if they're not provided
  workers ||= get_chunk_workers(foreman_addr, num_chunks_requested)
  
  # Deduct credits from foreman (fails if insufficient credits)
  atomic_deduct_credits(foreman_addr, workers.length)

  chunks = {}
  num_chunks = workers.length / WORKERS_PER_CHUNK
  num_chunks.times do
    chunk_id = REDIS.incr("chunks").to_s
    chunk_workers = workers.pop(WORKERS_PER_CHUNK)
    chunk_key = generate_chunk_key
    REDIS.hmset("chunks:#{chunk_id}", "foreman", foreman_addr,
                                      "workers", chunk_workers.join(','),
                                      "key", chunk_key)
    REDIS.expire("chunks:#{chunk_id}", DEFAULT_CHUNK_TTL)
    chunks[chunk_id] = chunk_workers.map{ |w| w + ':' + REDIS.hget("clients:#{w}", "port") } # Append workers' ports to address
  end
  return chunks
end

# Threadsafe way of doing chunk deletion. Prevents foreman from trying to both
# get a chunk key and get a "refund" for it
def atomic_delete_chunk(chunk_id, foreman_addr, valid)
  REDIS.lock("chunks:#{chunk_id}", LOCK_TIMEOUT, LOCK_MAX_ATTEMPTS)
  
  chunk = get_chunk(chunk_id)
  
  # Check existence and validity before deletion
  raise UnknownChunk unless (chunk != {}) && (chunk["foreman"] == foreman_addr)
  
  REDIS.del("chunks:#{chunk_id}")
  if valid
    chunk["workers"].split(",").each do |worker|
      REDIS.hincrby("clients:#{worker}", "credits", 1)
      REDIS.hincrby("clients:#{worker}", "chunks_complete", 1)
    end
    { :key => chunk["key"] }
  else
    { :credits => REDIS.hincrby("clients:#{foreman_addr}", "credits", WORKERS_PER_CHUNK) }
  end
ensure
  REDIS.unlock("chunks:#{chunk_id}")
end
