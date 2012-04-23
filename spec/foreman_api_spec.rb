require 'spec_helper'

describe 'Foreman API' do
  
  def app
    Sinatra::Application
  end
  
  addrs = []

  before(:each) do
    REDIS.flushdb
    addrs = generate_addrs(12)
    seed_db_with_workers(addrs)
  end
  
  it "gives you chunks when you request them" do
    post '/chunks?n=2'
    last_response.should be_ok
    response = JSON.parse(last_response.body)

    response.keys.length.should == 2
    response.each_value.each do |workers|
      workers.length.should == 3
    end
  end
  
  it "lets you request workers if you've never registered before" do
    REDIS.flushdb
    addrs = generate_addrs(10)
    addrs.delete("127.0.0.1")
    seed_db_with_workers(addrs)
    post '/chunks?n=2'
    last_response.should be_ok
  end
  
  it "removes credits from your account for requesting chunks" do
    post '/chunks?n=2'
    get '/workers/127.0.0.1'
    response = JSON.parse(last_response.body)
    response["credits"].to_i.should == 6
  end
  
  it "lets you spend all your credits" do
    post '/chunks?n=4'
    last_response.should be_ok
  end
  
  it "gives you valid workers (unique; correct ports; not timed out; doesn't assign foreman to itself)" do
    new_addr = generate_addrs(1)
    add_worker(new_addr, 1234, -1)
    post '/chunks?n=4'
    all_workers = []
    response = JSON.parse(last_response.body)
    response.each_value.each do |workers|
      workers.each do |worker_pair|
        addr, port = worker_pair.split(":")
        all_workers << addr
        addr.should_not == '127.0.0.1'
        worker = get_client(addr)
        worker["port"].should == port
        worker["expiry"].to_i.should > Time.now.to_i 
      end
    end
    all_workers.uniq == all_workers
  end
  
  it "doesn't give you chunks unless you have enough credits" do
    addrs = generate_addrs(100)
    seed_db_with_workers(addrs)
    post '/chunks?n=20'
    last_response.status.should == 406
  end
    
  it "returns the right key; doesn't return credits when you report that a chunk is correct" do
    post '/chunks?n=4'
    chunks = JSON.parse(last_response.body)
    chunks.each_pair do |chunk_id, workers|
      actual_key = REDIS.hget("chunks:#{chunk_id}", "key")
      delete "/chunks/#{chunk_id}?valid=1"
      last_response.should be_ok
      response = JSON.parse(last_response.body)
      response["key"].should == actual_key
      get_client("127.0.0.1")["credits"].to_i.should == 0
    end
  end
  
  it "doesn't return a key; returns your credits when you report that a chunk is incorrect" do
    post '/chunks?n=4'
    chunks = JSON.parse(last_response.body)
    chunks.each_pair do |chunk_id, workers|
      actual_key = REDIS.hget("chunks:#{chunk_id}", "key")
      delete "/chunks/#{chunk_id}"
      last_response.should be_ok
      response = JSON.parse(last_response.body)
      response["key"].should be_nil
    end
    get_client("127.0.0.1")["credits"].to_i.should == 12
  end
      
  it "doesn't let you report that a chunk is correct then incorrect" do
    post '/chunks?n=4'
    chunks = JSON.parse(last_response.body)
    chunks.each_pair do |chunk_id, workers|
      actual_key = REDIS.hget("chunks:#{chunk_id}", "key")
      delete "/chunks/#{chunk_id}"
      last_response.should be_ok
      delete "/chunks/#{chunk_id}?valid=1"
      last_response.status.should == 404
    end
  end
  
  it "doesn't let you report that a chunk is incorrect, then correct" do
    post '/chunks?n=4'
    chunks = JSON.parse(last_response.body)
    chunks.each_pair do |chunk_id, workers|
      actual_key = REDIS.hget("chunks:#{chunk_id}", "key")
      delete "/chunks/#{chunk_id}?valid=1"
      last_response.should be_ok
      delete "/chunks/#{chunk_id}"
      last_response.status.should == 404
    end
  end
  
  it "doesn't let you delete non-existent chunks" do
    delete "/chunks/999"
    last_response.status.should == 404
  end
  
  it "doesn't let you delete chunks that aren't yours" do
    make_chunks(4, "255.255.255.255", addrs)
    chunks = JSON.parse(last_response.body)
    chunks.each_pair do |chunk_id, workers|
      delete "/chunks/#{chunk_id}"
      last_response.status.should == 404
    end
  end
end