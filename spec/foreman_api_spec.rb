require './spec/spec_helper'

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
  
  it "gives you tasks when you request them" do
    post '/tasks?n=2'
    last_response.should be_ok
    response = JSON.parse(last_response.body)
    response.keys.length.should == 2
    response.each_value.each do |workers|
      workers.length.should == WORKERS_PER_CHUNK
    end
  end
  
  it "lets you request just one task" do
    post '/tasks'
    last_response.should be_ok
    response = JSON.parse(last_response.body)
    response.keys.length.should == 1
    response.each_value.each do |workers|
      workers.length.should == WORKERS_PER_CHUNK
    end
  end
  
  it "lets you request workers if you've never registered before" do
    REDIS.flushdb
    addrs = generate_addrs(10)
    addrs.delete("127.0.0.1")
    seed_db_with_workers(addrs)
    post '/tasks?n=2'
    last_response.should be_ok
  end
  
  it "removes credits from your account for requesting tasks" do
    post '/tasks?n=2'
    foreman = get_client("127.0.0.1")
    foreman["credits"].to_i.should == NUM_STARTING_CREDITS - 2 * WORKERS_PER_CHUNK
  end
  
  it "lets you spend all your credits" do
    post '/tasks?n=4'
    last_response.should be_ok
  end
  
  it "gives you valid workers (unique; correct ports; not timed out; doesn't assign foreman to itself)" do
    new_addr = generate_addrs(1)
    add_worker(new_addr, 1234, -1)
    post '/tasks?n=4'
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
  
  it "doesn't give you tasks unless you have enough credits" do
    addrs = generate_addrs(100)
    seed_db_with_workers(addrs)
    post '/tasks?n=20'
    last_response.status.should == 406
  end
    
  it "returns the right key; doesn't return credits; pays workers when you report that a task is correct" do
    post '/tasks?n=4'
    tasks = JSON.parse(last_response.body)
    tasks.each_pair do |task_id, workers|
      actual_key = REDIS.hget("tasks:#{task_id}", "key")
      worker_credits = {}
      workers.each do |worker_pair|
        addr, port = worker_pair.split(":")
        worker_credits[addr] = get_client(addr)["credits"].to_i
      end
      delete "/tasks/#{task_id}?valid=1"
      last_response.should be_ok
      response = JSON.parse(last_response.body)
      response["key"].should == actual_key
      get_client("127.0.0.1")["credits"].to_i.should == 0
      worker_credits.each_pair do |addr, credits|
        (credits + 1).should == get_client(addr)["credits"].to_i
      end
    end
  end
  
  it "doesn't return a key; returns your credits; doesn't pay workers when you report that a task is incorrect" do
    post '/tasks?n=4'
    tasks = JSON.parse(last_response.body)
    tasks.each_pair do |task_id, workers|
      actual_key = REDIS.hget("tasks:#{task_id}", "key")
      worker_credits = {}
      workers.each do |worker_pair|
        addr, port = worker_pair.split(":")
        worker_credits[addr] = get_client(addr)["credits"].to_i
      end
      delete "/tasks/#{task_id}"
      last_response.should be_ok
      response = JSON.parse(last_response.body)
      response["key"].should be_nil
      response["credits"].should be_a(Fixnum)
      worker_credits.each_pair do |addr, credits|
        credits.should == get_client(addr)["credits"].to_i
      end
    end
    get_client("127.0.0.1")["credits"].to_i.should == 12
  end
      
  it "doesn't let you report that a task is correct then incorrect" do
    post '/tasks?n=4'
    tasks = JSON.parse(last_response.body)
    tasks.each_pair do |task_id, workers|
      actual_key = REDIS.hget("tasks:#{task_id}", "key")
      delete "/tasks/#{task_id}"
      last_response.should be_ok
      delete "/tasks/#{task_id}?valid=1"
      last_response.status.should == 404
    end
  end
  
  it "doesn't let you report that a task is incorrect, then correct" do
    post '/tasks?n=4'
    tasks = JSON.parse(last_response.body)
    tasks.each_pair do |task_id, workers|
      actual_key = REDIS.hget("tasks:#{task_id}", "key")
      delete "/tasks/#{task_id}?valid=1"
      last_response.should be_ok
      delete "/tasks/#{task_id}"
      last_response.status.should == 404
    end
  end
  
  it "doesn't let you delete non-existent tasks" do
    delete "/tasks/999"
    last_response.status.should == 404
  end
  
  it "doesn't let you delete tasks that aren't yours" do
    foreman = addrs.shift
    tasks = make_tasks(foreman, addrs.length / WORKERS_PER_CHUNK, addrs)
    tasks.each_pair do |task_id, workers|
      delete "/tasks/#{task_id}"
      last_response.status.should == 404
    end
  end
end