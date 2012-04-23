ENV['RACK_ENV'] = 'test'

require './discovery'
require 'rack/test'

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
end

class Array
  # Basic set equality on arrays. Just sort them and chek that they're the same
  def set_eq(s)
    self.sort == s.sort
  end
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
