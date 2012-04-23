require 'spec_helper'
  
describe 'Worker API' do
  
  def app
    Sinatra::Application
  end
  
  addrs = []

  before(:each) do
    REDIS.flushdb
    addrs = generate_addrs(10)
    seed_db_with_workers(addrs)
  end
  
  it 'gives you credits when you register' do
    addrs.each do |addr|
      get "/workers/#{addr}"
      response = JSON.parse(last_response.body)
      response["credits"].to_i.should == NUM_STARTING_CREDITS
    end
  end
  
  it "doesn't give you more credits when you register again" do
    addr = addrs.last
    post "/#{addr}"
    get "/workers/#{addr}"
    response = JSON.parse(last_response.body)
    response["credits"].to_i.should == NUM_STARTING_CREDITS
  end
  
  it "doesn't give you more credits after a delete" do
    addr = addrs.pop
    delete "/workers/#{addr}"
    post "/workers", params={:addr=>addr}
    get "/workers/#{addr}"
    response = JSON.parse(last_response.body)
    response["credits"].to_i.should == NUM_STARTING_CREDITS
  end
  
  it "doesn't reset your credits when you register again" do
    addr = addrs.last
    REDIS.hmset("clients:#{addr}", "credits", 50)
    post "/workers", params={:addr=>addr}
    get "/workers/#{addr}"
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

      