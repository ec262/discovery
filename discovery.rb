require 'sinatra'
require 'json'
require 'set'

NUM_STARTING_CREDITS = 12

configure do
  require 'redis'
  uri = URI.parse(ENV["REDISTOGO_URL"])
  REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
end

configure :production, :development do
  REDIS.select(0)
end

configure :development, :test do
  require 'system_timer'
end

configure :test do
  REDIS.select(1) # Use a different test DB
  REDIS.flushdb
end

get '/' do
  all_workers = REDIS.smembers("workers")
  all_workers.to_json
end

get '/:addr' do
  if worker = REDIS.hgetall(params[:addr])
    worker.to_json
  else
    status 404
    body "No information about that worker"
  end
end

post '/?:addr?' do
  addr = params[:addr] || request.ip
  
  # Give the worker credits if they haven't registered before
  credits = REDIS.hget(addr, "credits") || NUM_STARTING_CREDITS
  
  result = REDIS.multi do 
    REDIS.sadd("workers", addr)
    REDIS.hset(addr, "time", Time.now.to_i)
    REDIS.hset(addr, "credits", credits)
  end
  
  if result
    "'OK'"
  else
    status 500
    body "Failed to add to workers pool :/"
  end
end

delete '/?:addr?' do
  addr = params[:addr] || request.ip
  REDIS.srem("workers", addr)
  "'OK'" # Return OK even if srem returns false (when there is no such member)
end