require 'sinatra'
require 'json'
require 'set'

require './lib/chunks'
require './lib/workers'
require './lib/exceptions'

NUM_STARTING_CREDITS = 12
DEFAULT_PORT = 2626
DEFAULT_WORKER_TTL = 60
DEFAULT_CHUNK_TTL = 86400 # 1 day
LOCK_TIMEOUT = 10
LOCK_MAX_ATTEMPTS = 100
WORKERS_PER_CHUNK = 3

configure do
  # Set up Redis
  require 'redis'
  require 'redis-lock'
  uri = URI.parse(ENV["REDISTOGO_URL"])
  REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)

  # Needed for ruby 1.8.x compatibility
  require 'system_timer' if RUBY_VERSION =~ /^1.8/
  
  # Encode JSON correctly
  set :json_encoder, :to_json 
  
  # Use custom exception handling
  set :raise_errors, Proc.new { false }
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

# Very basic Rack middleware that converts everything to JSON.
# Basically, it lets us respond from Sinatra with straight Ruby instead of
# tediously calling "to_json" every time.
# class JSONResponder
#   def initialize(app)
#     @app = app
#   end
#   
#   def call(env)
#     status, headers, response = @app.call(env)
#     json_response = response.to_json
#     headers["Content-Type"] = 'application/json;charset=utf-8'
#     headers["Content-Length"] = json_response.length.to_s
#     [status, headers, json_response]
#   end
# end
# 
# use JSONResponder

