ENV['RACK_ENV'] = 'test'

require './discovery'
require 'rack/test'

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
end

class Array
  # A method to do set equality on arrays. If two arrays are the same, they have
  # the same length and their intersection is the same length as the original
  def set_eq(s)
    (self.size == s.size) && (self.size == (self & s).size)
  end
end

def generate_addrs(n)
  Array.new(n).map do
    Array.new(4).map{rand(256)}.join('.')
  end
end

def seed_db_with_workers(addrs)
  post "/workers"
  addrs.each do |addr|
    post "/workers", params={:addr=>addr}
  end
end
