require 'spec_helper'

describe 'The Discovery Service' do
  
  def app
    Sinatra::Application
  end
  
  addrs = []
  
  before(:each) do
    REDIS.flushdb
    addrs = generate_addrs(10)
    seed_db_with_workers(addrs)
  end
    
  it "adds workers to the set" do
    last_response.should be_ok
  end
  
  it "adds correct default TTLs and ports" do
    get "/workers/#{addrs.last}"
    response = JSON.parse(last_response.body)
    response["expiry"].to_i.should == Time.now.to_i + DEFAULT_WORKER_TTL
    response["port"].to_i.should == 2626
  end
  
  it "adds/updates correct TTLs and ports" do
    t = Time.now.to_i
    post "/workers", params={:addr=>"jon-levine.com", :ttl=>20, :port=>8302}
    get "/workers/jon-levine.com"
    response = JSON.parse(last_response.body)
    response["expiry"].to_i.should == t + 20
    response["port"].to_i.should == 8302
  end
  
  it "doesn't return workers that have expired" do
    post "/workers", params={:addr=>"jon-levine.com", :ttl=>-1} # don't do this IRL
    get "/workers"
    response = JSON.parse(last_response.body)
    response.include?("jon-levine.com").should be_false
  end

  it "gets a list of workers" do
    get '/workers'
    last_response.should be_ok
    response = JSON.parse(last_response.body)
    response.set_eq(addrs).should be_true
  end
  
  it "deletes workers from the set" do
    del_addrs = Array.new(addrs)
    
    # Delete a bunch of addresses, including garbage values, make sure it works
    del_addrs.delete("127.0.0.1")
    delete '/workers'
    last_response.should be_ok  
    
    delete "/workers/#{del_addrs.pop}"
    last_response.should be_ok
    
    delete '/workers/garbage'
    last_response.should be_ok
    
    get '/workers'
    
    response = JSON.parse(last_response.body)
    response.set_eq(del_addrs).should be_true
  end
  
end
