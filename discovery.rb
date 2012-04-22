require 'sinatra'
require 'json'
require 'set'

NUM_STARTING_CREDITS = 12
DEFAULT_PORT = 2626
DEFAULT_WORKER_TTL = 60
DEFAULT_CHUNK_TTL = 86400 # 1 day


configure do
  # Set up Redis
  require 'redis'
  uri = URI.parse(ENV["REDISTOGO_URL"])
  REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)

  # Use the system timer gem if running on Ruby 1.8
  require 'system_timer' if RUBY_VERSION =~ /^1.8/
end

configure :production, :development do
  REDIS.select(0) # Use default database
end

configure :development, :test do
end

configure :test do
  REDIS.select(1) # Use a different test DB
  REDIS.flushdb
end

#########################################
########### Foreman Methods #############
#########################################

require 'lib/foreman_api'

post '/chunks' do
  foreman = request.ip
  num_chunks = params[:n]
  workers = get_workers(num_chunks * 3)
  workers.delete(foreman) # Make sure workers don't include foreman
  
  # Round workers down to multiple of 3, update num_chunks
  num_workers = workers.length - (workers.length % 3)
  workers = workers.take(num_workers)
  num_chunks = workers.length / 3
  
  # Make sure Foreman has enough credits
  available_credits = REDIS.hget("clients:#{foreman}", "credits")
  if available_credits < workers.length
    status 406
    body "\"Sorry, do you do not have sufficient credits to request this many chunks.
          (Need #{workers.length}, only have #{available_credits}.)\""
    return
  end
  
  # Assign workers to chunks and generate keys
  chunks = {} 
  num_chunks.times do
    chunk_id = REDIS.incr("chunks")
    chunk_workers = workers.pop(3)
    chunk_key = generate_chunk_key
    REDIS.hmset("chunks:#{chunk_id}", "foreman", foreman, "workers", chunk_workers.join(','), "key", chunk_key)
    REDIS.expire("chunks:#{chunk_id}", DEFAULT_CHUNK_TTL)
    
    # Append ports of workers to their address for foreman
    chunk[chunk_id] = chunk_workers.map{ |w| w + ':' + REDIS.hget("clients:#{w}", "port") }
  end

  # Dock credits from foreman and return
  REDIS.hincrby("clients:#{foreman}", "credits",  -workers.length)
  chunks.to_json
end

delete '/chunks/:id' do
  foreman = request.ip
  chunk = REDIS.hgetall("chunks:#{params[:id]}")
  
  # Make sure everything's valid
  if chunk == {}
    status 404
    body "\"Chunk expired or does not exist.\""
    return
  elsif chunk["foreman"] != foreman
    status 403
    body "\"You do not have permission to delete this chunk.\""
    return
  end
  
  # IF so, delete and decide what to do
  REDIS.del("chunks:#{params[:id]}")
  if params[:valid].to_i == 1
    chunk[:key].to_json
  else
    REDIS.hincrby("clients:#{request.ip}", 3)
    "\"Three credits have been restored.\""
  end
end

#########################################
########### Worker Methods ##############
#########################################

require 'lib/worker_api'

post '/workers' do
  addr = params[:addr] || request.ip
  port = params[:port] || DEFAULT_PORT
  ttl = params[:ttl] || DEFAULT_WORKER_TTL
      
  if add_worker(addr, port, ttl)
    '"OK"'
  else
    status 500
    body '"Failed to add to workers pool :/"'
  end
end

get '/chunks/:id' do
  chunk = REDIS.hmget("chunks:#{params[:id]}")
  if chunk["workers"].split(',').index(request.ip)
    "\"#{chunk["key"]}\""
  else
    status 403
    body "\"You do not have permission to get this key.\""
  end
end

#########################################
######## Development Methods ############
#########################################

get '/' do 
  request.ip
end

get '/workers' do  
  get_workers.to_json
end

get '/workers/:addr' do
  if worker = REDIS.hgetall("clients:#{params[:addr]}")
    worker.to_json
  else
    status 404
    body '"No information about that worker"'
  end
end

delete '/workers/?:addr?' do
  addr = params[:addr] || request.ip
  REDIS.zrem("workers", addr)
  '"OK"' # Return OK even if srem returns false (when there is no such member)
end

