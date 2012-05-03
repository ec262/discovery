require './spec/spec_helper'
  
describe 'Worker API' do
  
  def app
    Sinatra::Application
  end

  before(:each) do
    REDIS.flushdb
  end
  
  it "allows you to register" do
    post "/workers"
    last_response.should be_ok
    worker = last_response.json
    worker["addr"].should == "127.0.0.1"
  end
  
  it "adds correct default TTLs and ports" do
    post "/workers"
    worker = get_client("127.0.0.1")
    worker["expiry"].to_i.should == Time.now.to_i + DEFAULT_WORKER_TTL
    worker["port"].to_i.should == DEFAULT_PORT
  end
  
  it "adds/updates correct TTLs and ports" do
    t = Time.now.to_i
    post "/workers", params={:ttl=>20, :port=>8302}
    worker = get_client("127.0.0.1")
    worker["expiry"].to_i.should == t + 20
    worker["port"].to_i.should == 8302
  end
  
  it 'gives you credits when you register' do
    post "/workers"
    worker = get_client("127.0.0.1")
    worker["credits"].to_i.should == NUM_STARTING_CREDITS
  end

  it "doesn't give you more credits when you register again" do
    # register once
    post "/workers"
    worker = get_client("127.0.0.1")
    worker["credits"].to_i.should == NUM_STARTING_CREDITS
    # register again
    post "/workers"
    worker = get_client("127.0.0.1")
    worker["credits"].to_i.should == NUM_STARTING_CREDITS
  end
  
  it "doesn't reset your credits when you register again" do
    # register once
    post "/workers"
    worker = get_client("127.0.0.1")
    worker["credits"].to_i.should == NUM_STARTING_CREDITS
    # change credits
    REDIS.hmset("clients:127.0.0.1", "credits", 50)
    # register again
    post "/workers", params={:port=>1234}
    worker = get_client("127.0.0.1")
    worker["credits"].to_i.should == 50
    # ensure we've actually checked the correct worker
    worker["port"].to_i.should == 1234
  end
  
  it "returns a key if you're assigned to a task" do
    # setup workers & task
    workers = generate_addrs(WORKERS_PER_CHUNK-1) # +1 localhost
    seed_db_with_workers(workers)
    tasks = make_tasks("1.2.3.4", 1, workers)
    task_id = tasks.keys.first
    # request task key
    get "/tasks/#{task_id}"
    last_response.should be_ok
    response = last_response.json
    response["key"].should == REDIS.hget("tasks:#{task_id}", "key")
  end
  
  it "doesn't return a key if you're not assigned to a task" do
    # setup workers & task
    workers = generate_addrs(WORKERS_PER_CHUNK, false)
    seed_db_with_workers(workers)
    tasks = make_tasks("1.2.3.4", 1, workers)
    task_id = tasks.keys.first
    # request task key
    get "/tasks/#{task_id}"
    last_response.status.should == 404
    response = last_response.json
    response["key"].should be_nil
  end
  
end  
