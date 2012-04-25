require './spec/spec_helper'
  
describe 'Worker API' do
  
  def app
    Sinatra::Application
  end
  
  addrs = []
  
  before(:each) do
    REDIS.flushdb
    addrs = generate_addrs(12)
    seed_db_with_workers(addrs)
  end
  
  it "allows you to register" do
    REDIS.flushdb
    post "/workers"
    last_response.should be_ok
    worker = JSON.parse(last_response.body)
    worker["addr"].should == "127.0.0.1"
  end
  
  it "adds correct default TTLs and ports" do
    worker = get_client(addrs.last)
    worker["expiry"].to_i.should == Time.now.to_i + DEFAULT_WORKER_TTL
    worker["port"].to_i.should == DEFAULT_PORT
  end
  
  it "adds/updates correct TTLs and ports" do
    REDIS.flushdb
    t = Time.now.to_i
    post "/workers", params={:ttl=>20, :port=>8302}
    worker = get_client("127.0.0.1")
    worker["expiry"].to_i.should == t + 20
    worker["port"].to_i.should == 8302
  end
  
  it 'gives you credits when you register' do
    addrs.each do |addr|
      worker = get_client(addr)
      worker["credits"].to_i.should == NUM_STARTING_CREDITS
    end
  end
  
  it "doesn't give you more credits when you register again" do
    addr = addrs.last
    post "/#{addr}"
    worker = get_client(addr)
    worker["credits"].to_i.should == NUM_STARTING_CREDITS
  end
  
  it "doesn't give you more credits after a delete" do
    addr = addrs.pop
    delete "/workers/#{addr}"
    post "/workers", params={:addr=>addr}
    worker = get_client(addr)
    worker["credits"].to_i.should == NUM_STARTING_CREDITS
  end
  
  it "doesn't reset your credits when you register again" do
    addr = addrs.last
    REDIS.hmset("clients:#{addr}", "credits", 50)
    post "/workers", params={:addr=>addr}
    worker = get_client(addr)
    worker["credits"].to_i.should == 50
  end
  
  it "returns a key if you're assigned to a chunk" do
    workers = addrs.take(2).push("127.0.0.1")
    chunks = make_chunks("1.2.3.4", 1, workers)
    chunk_id = chunks.keys.first
    get "/chunks/#{chunk_id}"
    last_response.should be_ok
    response = JSON.parse(last_response.body)
    response["key"].should == REDIS.hget("chunks:#{chunk_id}", "key")
  end
  
  it "doesn't return a key if you're not assigned to a chunk" do
    workers = addrs.take(WORKERS_PER_CHUNK)
    workers.delete("127.0.0.1") # Make sure localhost isn't in workers
    workers.length.should == WORKERS_PER_CHUNK
    chunks = make_chunks("1.2.3.4", 1, workers)
    chunk_id = chunks.keys.first
    get "/chunks/#{chunk_id}"
    last_response.status.should == 404
    response = JSON.parse(last_response.body)
    response["key"].should be_nil
  end
  
end  

      