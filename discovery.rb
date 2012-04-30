require 'sinatra'
require './config'

#########################################
########### Foreman Methods #############
#########################################

# POST /tasks?n=num_tasks
# Pay for a list of tasks and their associated workers; returns at most
# num_tasks tasks (possibly less)
post '/tasks' do
  foreman_addr = request.ip
  num_tasks_requested = (params[:n] || 1).to_i  
  make_tasks(foreman_addr, num_tasks_requested)  
end


# DELETE /tasks/:id(?valid=1)
# If a task is valid, return a key and give credits to workers. Otherwise
# restore credits to the foreman and return how many credits the foreman has.
# If request is invalid, don't tell the user whether the task doesn't exist or
# they simply don't have access
delete '/tasks/:id' do
  foreman_addr = request.ip
  task_id = params[:id]
  valid = (params[:valid] == '1')
  atomic_delete_task(task_id, foreman_addr, valid)
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

# GET /tasks/:id
# Return a key to workers involved in a task
get '/tasks/:id' do
  client_addr = request.ip
  task_id = params[:id]
  get_task_key(task_id, client_addr)
end

# GET /
# Returns info about the requester
get '/' do
  get_client(request.ip)
end

#########################################
######### Development stuff #############
#########################################

# Danger! Deletes the database and seeds it
get '/seed' do
  REDIS.flushdb
  seed_db(request.ip)
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
