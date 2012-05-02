require './spec/spec_helper'

describe 'Foreman API' do
  
  def app
    Sinatra::Application
  end

  def worker_addrs(response_obj)
    addrs = []
    response_obj.each_value do |workers|
      workers.each do |worker_pair|
        addr, port = worker_pair.split(':')
        addrs << ({ addr: addr, port: port })
      end
    end
    return addrs
  end

  
  addrs = []

  before(:each) do
    REDIS.flushdb
    addrs = generate_addrs(12)
    seed_db_with_workers(addrs)
  end
  
  it "gives you tasks when you request them" do
    post '/tasks'
    last_response.should be_ok
  end

  it "lets you request just one task" do
    post '/tasks'
    response = JSON.parse(last_response.body)
    response.keys.length.should == 1
  end

  it "gives you the correct number of tasks" do
    post '/tasks?n=3'
    response = JSON.parse(last_response.body)
    response.keys.length.should == 3
  end

  it "gives you the correct number of workers per task" do
    post '/tasks'
    response = JSON.parse(last_response.body)
    response.each_value.each do |workers|
      workers.length.should == WORKERS_PER_CHUNK
    end
  end 
  
  it "lets you request workers if you've never registered before" do
    REDIS.flushdb
    addrs = generate_addrs(12, false)
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

  it "doesn't give you tasks unless you have enough credits" do
    addrs = generate_addrs(100)
    seed_db_with_workers(addrs)
    post '/tasks?n=20'
    last_response.status.should == 406
  end

  it "doesn't assign the foreman to himself" do
    # seed db so a completely filled request must include the foreman
    REDIS.flushdb
    seed_db_with_workers(generate_addrs(11))
    post '/tasks?n=4'
    response = JSON.parse(last_response.body)
    worker_addrs(response).each do |h|
      h[:addr].should_not == '127.0.0.1'
    end
    # request thus should not have been completely filled
    response.count.should == 3
  end

  it "gives unique workers" do
    post '/tasks?n=4'
    response = JSON.parse(last_response.body)
    workers = worker_addrs(response).map{ |h| h[:addr] }
    workers.uniq.should == workers
  end

  it "doesn't give timed-out workers" do
    # seed db so a completely filled request must include the timed-out worker
    REDIS.flushdb
    seed_db_with_workers(generate_addrs(11))
    add_worker(generate_addrs(1), 1234, -1)
    post '/tasks?n=4'
    response = JSON.parse(last_response.body)
    worker_addrs(response).each do |h|
      worker = get_client(h[:addr])
      worker["expiry"].to_i.should > Time.now.to_i 
    end
    # request thus should not have been completely filled
    response.count.should == 3
  end

  it "gives the correct port for workers" do
    post '/tasks?n=4'
    response = JSON.parse(last_response.body)
    worker_addrs(response).each do |h|
      worker = get_client(h[:addr])
      worker["port"].should == h[:port]
    end
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
