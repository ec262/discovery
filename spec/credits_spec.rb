require 'spec_helper'

describe "The Credit System" do
  
  def app
    Sinatra::Application
  end
  
  addrs = []
  
  before(:each) do
    REDIS.flushdb
    post '/'
    addrs = ["127.0.0.1", "example.com", "tom-buckley.com:8931"]
    addrs.each do |addr|
      post "/#{addr}"
    end
  end
  
  describe 'Worker API' do
    it 'gives you credits when you register' do
      addrs.each do |addr|
        get "/#{addr}"
        response = JSON.parse(last_response.body)
        response["credits"].to_i.should == NUM_STARTING_CREDITS
      end
    end
    
    it "doesn't give you more credits when you register again" do
      addr = addrs.last
      post "/#{addr}"
      get "/#{addr}"
      response = JSON.parse(last_response.body)
      response["credits"].to_i.should == NUM_STARTING_CREDITS
    end
    
    it "doesn't give you more credits after a delete" do
      addr = addrs.pop
      delete "/#{addr}"
      post "/#{addr}"
      get "/#{addr}"
      response = JSON.parse(last_response.body)
      response["credits"].to_i.should == NUM_STARTING_CREDITS
    end
    
    it "doesn't reset your credits when you register again" do
      addr = addrs.last
      REDIS.hmset(addr, "credits", 50)
      post "/#{addr}"
      get "/#{addr}"
      response = JSON.parse(last_response.body)
      response["credits"].to_i.should == 50
    end
    
    it "gives you credits for doing correct work" do
    end
    
    it "doesn't give you credits for incorrect work" do
    end
    
    it "returns a key if you're assigned to a chunk" do
    end
    
    it "doesn't return a key if you're not assigned to a chunk" do
    end
    
    it "times out registration after the given period" do
    end
    
  end  
  
  
  describe 'Foreman API' do
    it "gives you well-formed chunks" do
    end
    
    it "removes credits from your account for requesting chunks" do
    end
    
    it "only assigns you workers that have not timed out" do
    end
    
    it "doesn't give you chunks unless you have enough credits" do
    end
    
    it "doesn't assign foremen to their own job" do
    end
    
    it "returns the right key when you report that a chunk is correct" do
    end
    
    it "doesn't return a key when you report that a chunk is incorrect" do
    end
    
    it "returns your credits when you report that a chunk is incorrect" do
    end
    
    it "doesn't return credits when you report that a chunk is correct" do
    end
    
    it "doesn't let you report that a chunk is correct then incorrect" do
    end
    
    it "doesn't let you report that a chunk is incorrect, then correct" do
    end
    
  end
        
end