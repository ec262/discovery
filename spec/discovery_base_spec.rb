require 'spec_helper'

describe 'The Discovery Service' do
  
  def app
    Sinatra::Application
  end
  
  addrs = []
  
  # Flush the database before each test and add the specified addresses.
  # Also just do a regular post along with "127.0.0.1"; should be the same.
  # Because of set inclusion, there should be no duplicates
  before(:each) do
    REDIS.flushdb
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
    del_addrs = Array.new(addrs)
    
    # Delete a bunch of addresses, including garbage values, make sure it works
    del_addrs.delete("127.0.0.1")
    delete '/'
    last_response.should be_ok  
    
    delete "/#{del_addrs.pop}"
    last_response.should be_ok
    
    delete '/garbage'
    last_response.should be_ok
    
    get '/'
    
    response = JSON.parse(last_response.body)
    response.set_eq(del_addrs).should be_true
  end
end
