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
  make_chunks(foreman_addr, num_chunks_requested)  
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
  atomic_delete_chunk(chunk_id, foreman_addr, valid)
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
  add_worker(addr, port, ttl)
end

# GET /chunks/:id
# Return a key to workers involved in a chunk
get '/chunks/:id' do
  client_addr = request.ip
  chunk_id = params[:id]
  get_chunk_key(chunk_id, client_addr)
end

# GET /
# Returns info about the requester
get '/' do
  get_client(request.ip)
end

#########################################
############ Error Handling #############
#########################################

# Library methods raise exceptions so that controller routes don't have to.
# This catches the ones we expect--they must be subclassed from
# DiscoveryServiceException and respond to a "code" method (http_status in
# Sinatra 1.4.x, but whatever)
error DiscoveryServiceException do
  exception = env['sinatra.error']
  status exception.code
  body exception.response
end

run! if app_file == $0
end
