require 'sinatra'
require 'json'

configure do
  require 'redis'
  uri = URI.parse(ENV["REDISTOGO_URL"])
  REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  puts "Setup Redis with host #{ uri.to_s }"
end

get '/' do
  all_workers = REDIS.smembers("workers")
  all_workers.to_json
end

post '/' do
  if REDIS.sadd("workers", request.ip).to_s
    "OK"
  else
    status 500
    body "Failed to add to workers pool :/"
  end
end

delete '/:ip' do
  if REDIS.srem("workers", params[:ip])
    "OK"
  else
    status 500
    body "Error in removing worker #{params[:ip]}"
  end
end