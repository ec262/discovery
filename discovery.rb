require 'sinatra'
require './config'

#########################################
########### Foreman Methods #############
#########################################

# POST /chunks?n=num_chunks
# Pay for a list of chunks and their associated workers; returns at most
# num_chunks chunks (could be less)

post '/chunks' do
  foreman_addr = request.ip
  num_chunks_requested = params[:n].to_i
  workers = get_chunk_workers(num_chunks_requested, foreman_addr)
  
  # Make sure foreman has enough credits
  if atomic_deduct_credits(workers.length, foreman_addr)
    # Number of chunks could be less than requested
    json make_chunks(workers.length / 3, foreman_addr, workers)
  else
    status 406
    json  :credits_needed => workers.length,
          :credits_available => get_client(foreman_addr)["credits"].to_i
  end
end


# DELETE /chunks/:id(?valid=1)
# If a chunk is valid, return a key and give credits to workers. Otherwise
# restore credits to the foreman and return how many credits the foreman has.
# If request is invalid, don't tell the user whether the chunk doesn't exist or
# they simply don't have access

delete '/chunks/:id' do
  foreman_addr = request.ip
  chunk_id = params[:id]
  valid = (params[:valid].to_i == 1)
  
  if result = atomic_delete_chunk(chunk_id, foreman_addr, valid)
    json result
  else
    status 404
    json :error => "Unknown chunk"
  end
end


#########################################
########### Worker Methods ##############
#########################################

# POST /workers?addr=A&port=P&ttl=T
# Register as a worker

post '/workers' do
  addr = params[:addr] || request.ip
  port = params[:port] || DEFAULT_PORT
  ttl = params[:ttl] || DEFAULT_WORKER_TTL
      
  if result = add_worker(addr, port, ttl)
    json result
  else
    status 500
    json :error => "Failed to add to workers pool"
  end
end

# GET /chunks/:id
# Return a key to workers involved in a chunk

get '/chunks/:id' do
  chunk = get_chunk(params[:id])
  
  # Make sure chunk exists
  if chunk == {}
    status 404
    json :error => "Chunk expired or does not exist."
  end
  
  # Make sure worker permitted to access key
  unless chunk["workers"].split(',').index(request.ip)
    status 403
    json :error => "You do not have permission to get this key."
  end
  
  json :key => chunk["key"]
end

#########################################
######## Development Methods ############
#########################################

get '/' do 
  status 404
  json :ip => request.ip
end

get '/workers' do  
  json get_all_workers
end

get '/workers/:addr' do
  worker = get_client(params[:addr])
  if worker == {}
    status 404
    json :error => "Unknown worker"
  else
    json worker
  end
end

delete '/workers/?:addr?' do
  addr = params[:addr] || request.ip
  REDIS.zrem("workers", addr)
  json :status => "OK" # Even if the worker didn't exist
end

