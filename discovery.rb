require 'sinatra'
require './config'

#########################################
########### Foreman Methods #############
#########################################

# POST /chunks?n=num_chunks
# Pay for a list of chunks and their associated workers; returns at most
# num_chunks chunks (possibly less)

post '/chunks' do
  foreman_addr = request.ip
  num_chunks_requested = (params[:n] || 1).to_i
  workers = get_chunk_workers(foreman_addr, num_chunks_requested)
  
  if chunks = make_chunks(foreman_addr, workers)
    json chunks
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
  valid = (params[:valid] == '1')
  
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

# POST /workers?port=P&ttl=T
# Register as a worker

post '/workers' do
  addr = request.ip
  port = params[:port]
  ttl = params[:ttl]
      
  if worker = add_worker(addr, port, ttl)
    json worker
  else
    status 500
    json :error => "Failed to add to workers pool"
  end
end

# GET /chunks/:id
# Return a key to workers involved in a chunk

get '/chunks/:id' do
  client_addr = request.ip
  chunk_id = params[:id]
  
  if chunk_key = get_chunk_key(chunk_id, client_addr)
    json :key => chunk_key
  else
    status 404
    json :error => "Unknown chunk"
  end
end

# GET /
# Returns info about the requester

get '/' do
  addr = request.ip
  
  if client = get_client(addr)
    json client
  else
    status 404
    json :error => "Unknown client #{request.ip}"
  end
end

