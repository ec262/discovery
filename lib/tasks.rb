# Returns everything known about a task
def get_task(task_id)
  REDIS.hgetall("tasks:#{task_id}")
end

# Generates a (theoretically) secure key for AES-128 encryption. 
def generate_task_key
  require 'openssl'
  require 'base64'
  Base64.strict_encode64(OpenSSL::Cipher.new("aes-128-ecb").random_key)
end

# Returns the key for a task if the client is permitted to see it; otherwise
# raises an UnknownTask exceptions
def get_task_key(task_id, client_addr)
  task = get_task(task_id)
  raise UnknownTask unless (task != {}) && task["workers"].split(',').index(client_addr)
  { :key => task["key"] }
end

# Gets as many workers as possible; ensure that the foreman is not in the list
# of workers; remove workers from the availability pool. Shuffles the returned
# workers so as not to bias based on TTL; we don't want workers to be more
# likely to be used because they use very long or short TTLs. Note that this is
# NOT threadsafe; it's totally possible that foreman will get "busy" workers,
# which could result in the task failing. Fortunately the the system is
# designed to tolerate that scenario (see docs)
def get_task_workers(foreman_addr, num_tasks_requested)
  num_workers = num_tasks_requested * WORKERS_PER_CHUNK
  workers = get_available_workers.shuffle.reject{ |w| w == foreman_addr }.take(num_workers)
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

# Assigns workers to tasks and generate keys. Task IDs are generated by
# incrementing the "tasks" key in Redis; this ensures atomicity. Each credit
# then gets three workers assigned to it, along with a key which is stored
# in Redis but not returned.  Can raise InsufficientCredits exception from
# atomic_deduct_credits. Returns a hash of the form
# { "1" => ["worker1:port", "worker2:port", "worker3:port"],
#   "2" => ["worker4:port", ...], ... }
def make_tasks(foreman_addr, num_tasks_requested, workers=nil)
  # Get a list of workers if they're not provided
  workers ||= get_task_workers(foreman_addr, num_tasks_requested)
  
  # Deduct credits from foreman (fails if insufficient credits)
  atomic_deduct_credits(foreman_addr, workers.length)

  tasks = {}
  num_tasks = workers.length / WORKERS_PER_CHUNK
  num_tasks.times do
    task_id = REDIS.incr("tasks").to_s
    task_workers = workers.pop(WORKERS_PER_CHUNK)
    task_key = generate_task_key
    REDIS.hmset("tasks:#{task_id}", "foreman", foreman_addr,
                                      "workers", task_workers.join(','),
                                      "key", task_key)
    # Set an expiration on tasks so they don't pollute Redis
    REDIS.expire("tasks:#{task_id}", DEFAULT_CHUNK_TTL)
    tasks[task_id] = task_workers.map{ |w| w + ':' + REDIS.hget("clients:#{w}", "port") } # Append workers' ports to address
  end
  return tasks
end

# Threadsafe way of doing task deletion. Prevents foreman from trying to both
# get a task key and get a "refund" for it. If task was valid, returns a key
# and gives credits to workers. Otherwise, refund credits to the foreman.
def atomic_delete_task(task_id, foreman_addr, valid)
  # Lock the task in question
  REDIS.lock("tasks:#{task_id}", LOCK_TIMEOUT, LOCK_MAX_ATTEMPTS)
  
  task = get_task(task_id)
  
  # Check existence and validity before deletion
  raise UnknownTask unless (task != {}) && (task["foreman"] == foreman_addr)
  
  REDIS.del("tasks:#{task_id}")
  if valid
    task["workers"].split(",").each do |worker|
      REDIS.hincrby("clients:#{worker}", "credits", 1)
      REDIS.hincrby("clients:#{worker}", "tasks_complete", 1) # Could be useful for analysis
    end
    { :key => task["key"] }
  else
    { :credits => REDIS.hincrby("clients:#{foreman_addr}", "credits", WORKERS_PER_CHUNK) }
  end
ensure
  REDIS.unlock("tasks:#{task_id}")
end
