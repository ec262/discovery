require 'sinatra'
require 'json'
require 'set'

configure :production, :development do
  require 'redis'
  uri = URI.parse(ENV["REDISTOGO_URL"])
  REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
end

configure :development, :test do
  require 'system_timer'
end

configure :test do
  require 'mock_redis'
  REDIS = MockRedis.new
end

get '/' do
  all_workers = REDIS.smembers("workers")
  all_workers.to_json
end

post '/?:addr?' do
  addr = params[:addr] || request.ip
  if REDIS.sadd("workers", addr).to_s
    "OK"
  else
    status 500
    body "Failed to add to workers pool :/"
  end
end

delete '/?:addr?' do
  addr = params[:addr] || request.ip
  REDIS.srem("workers", addr)
  "OK" # Return OK even if srem returns false (when there is no such member)
end