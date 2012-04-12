require 'sinatra'

configure do
  require 'redis'
  uri = URI.parse(ENV["REDISTOGO_URL"])
  REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  puts "Setup Redis with host #{ uri.to_s }"
end

get '/' do
  "Hello world"
end

post '/register' do
  REDIS.sadd("workers", request.ip)
end

get '/workers' do
  all_workers = REDIS.smembers("workers")
  live_workers = []
  all_workers.each do |w|
    # TODO: 
  end
  live_workers.to_json
end