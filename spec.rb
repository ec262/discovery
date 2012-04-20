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

describe 'Set Equality method' do
  a = [1, 2, 3]
  b = [1, 2, 3]
  c = [1, 2, 4]
  d = [1, 2]
  e = [1, 2, 3, 4]
  f = [1, 2, 2, 3]
  
  it 'works on equal arrays' do
    a.set_eq(b).should be_true
  end
  
  it 'fails on different arrays' do
    [c, d, e, f].each do |s|
      a.set_eq(s).should be_false
    end
  end
  
end

describe 'The Discovery Service' do
  
  def app
    Sinatra::Application
  end
  
  addrs = []
  # def addrs
  #   ["127.0.0.1", "example.com", "tom-buckley.com:8931"]
  # end
  
  # Flush the database before each test and add the specified addresses.
  # Also just do a regular post along with "127.0.0.1"; should be the same.
  # Because of set inclusion, there should be no duplicates
  before(:each) do
    REDIS.flushall
    post '/'
    addrs = ["127.0.0.1", "example.com", "tom-buckley.com:8931"]
    addrs.each do |addr|
      post "/#{addr}"
    end
  end
    
  it "adds workers to the set" do
    last_response.should be_ok
  end

  it "gets a list of workers" do
    get '/'
    last_response.should be_ok
    response = JSON.parse(last_response.body)
    response.set_eq(addrs).should be_true
  end
  
  it "deletes workers from the set" do
    del_addrs = addrs # copy addrs
    
    # Delete a bunch of addresses, including garbage values, make sure it works
    del_addrs.delete("127.0.0.1")
    delete '/'
    puts last_response.body
    last_response.should be_ok  
    
    delete "/#{del_addrs.pop}"
    last_response.should be_ok
    
    delete '/garbage'
    last_response.should be_ok
    
    get '/'
    response = JSON.parse(last_response.body)
    response.set_eq(addrs).should be_true
  end
end
