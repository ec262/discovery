ENV['RACK_ENV'] = 'test'

require './discovery'
require 'rack/test'

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
end

def generate_addrs(n)
  addrs = Array.new(n).map do
    Array.new(4).map{rand(256)}.join('.')
  end
  addrs << '127.0.0.1'
end

def seed_db_with_workers(addrs)
  post "/workers"
  addrs.each do |addr|
    post "/workers", params={:addr=>addr}
  end
end
