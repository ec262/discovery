require 'sinatra'
require 'json'
require 'redis'
require 'redis-lock'

require './lib/tasks'
require './lib/workers'
require './lib/exceptions'
require './lib/json_responder'

NUM_STARTING_CREDITS = 12
DEFAULT_PORT = 26262
DEFAULT_WORKER_TTL = 60
DEFAULT_CHUNK_TTL = 86400 # 1 day
LOCK_TIMEOUT = 10
LOCK_MAX_ATTEMPTS = 100
WORKERS_PER_CHUNK = 3

configure do
  # Set up Redis
  uri = URI.parse(ENV["REDISTOGO_URL"])
  REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  
  # Encode every response with JSON
  use JSONResponder
  
  # Use custom exception handling
  set :raise_errors, false
  set :show_exceptions, false
  set :use_code, true # Will be necessary in Sinatra 1.4.x
end

configure :production, :development do
  REDIS.select(0) # Use default database
end

configure :test do
  REDIS.select(1) # Use a different test DB
  REDIS.flushdb
end

