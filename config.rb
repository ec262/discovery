require 'sinatra'
require 'json'
require 'set'

require 'lib/foreman_api'
require 'lib/worker_api'

NUM_STARTING_CREDITS = 12
DEFAULT_PORT = 2626
DEFAULT_WORKER_TTL = 60
DEFAULT_CHUNK_TTL = 86400 # 1 day

configure do
  # Set up Redis
  require 'redis'
  uri = URI.parse(ENV["REDISTOGO_URL"])
  REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)

  # Use the system timer gem if running on Ruby 1.8
  require 'system_timer' if RUBY_VERSION =~ /^1.8/
end

configure :production, :development do
  REDIS.select(0) # Use default database
end

configure :development, :test do
end

configure :test do
  REDIS.select(1) # Use a different test DB
  REDIS.flushdb
end

