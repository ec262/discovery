ENV['RACK_ENV'] = 'test'

require './discovery'
require 'rack/test'

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
end

class Rack::MockResponse
  def json
    JSON.parse(self.body)
  end
end