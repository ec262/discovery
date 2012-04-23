require 'sinatra'
require 'sinatra/json'
require 'json'
require 'set'

require './lib/chunks'
require './lib/workers'

NUM_STARTING_CREDITS = 12
DEFAULT_PORT = 2626
DEFAULT_WORKER_TTL = 60
DEFAULT_CHUNK_TTL = 86400 # 1 day
LOCK_TIMEOUT = 10
LOCK_MAX_ATTEMPTS = 100

configure do
  # Set up Redis
  require 'redis'
  require 'redis-lock'
  uri = URI.parse(ENV["REDISTOGO_URL"])
  REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)

  require 'system_timer' if RUBY_VERSION =~ /^1.8/ # Needed for ruby 1.8.x
  
  set :json_encoder, :to_json # not some other stupid encoder
end

configure :production, :development do
  REDIS.select(0) # Use default database
end

configure :test do
  # REDIS.select(1) # Use a different test DB
  REDIS.flushdb
end
