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
  workers = get_chunk_workers(params[:n], foreman_addr)
  
  # Make sure foreman has enough credits
  if atomic_deduct_credits(workers.length, foreman_addr)
    # Number of chunks could be less than requested
    make_chunks(workers.length / 3, foreman_addr).to_json
  else
    status 406
    {
      :credits_needed => workers.length,
      :credits_available => get_client(foreman_addr)["credits"]
    }.to_json
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
    result.to_json
  else
    status 404
    "Unknown chunk".to_json 
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
      
  if add_worker(addr, port, ttl)
    "OK".to_json
  else
    status 500
    "Failed to add to workers pool :/".to_json
  end
end

# GET /chunks/:id
# Return a key to workers involved in a chunk

get '/chunks/:id' do
  chunk = get_chunk(params[:id])
  
  # Make sure chunk exists
  if chunk == {}
    status 404
    return "Chunk expired or does not exist.".to_json
  end
  
  # Make sure worker permitted to access key
  unless chunk["workers"].split(',').index(request.ip)
    status 403
    return "You do not have permission to get this key.".to_json
  end
  
  chunk["key"].to_json
end

#########################################
######## Development Methods ############
#########################################

get '/' do 
  status 404
  request.ip.to_json
end

get '/workers' do  
  get_all_workers.to_json
end

get '/workers/:addr' do
  body worker = get_client(params[:addr]).to_json
  status 404 if worker == {}
end

delete '/workers/?:addr?' do
  addr = params[:addr] || request.ip
  REDIS.zrem("workers", addr)
  "OK".to_json # Return OK even if srem returns false (when there is no such member)
end

