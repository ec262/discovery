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
  
  describe "Task creation (POST /tasks)" do
    describe "Request" do
      it "lets you request tasks" do
        post '/tasks'
        last_response.should be_ok
      end

      it "lets you request just one task" do
        post '/tasks'
        response = last_response.json
        response.keys.length.should == 1
      end

      it "lets you request tasks if you've never registered before" do
        REDIS.flushdb
        addrs = generate_addrs(12, false)
        seed_db_with_workers(addrs)
        post '/tasks?n=2'
        last_response.should be_ok
      end

      it "gives you the correct number of tasks" do
        post '/tasks?n=3'
        response = last_response.json
        response.keys.length.should == 3
      end
    end
    
    describe "Credits" do
      it "removes the correct number of credits" do
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
    end

    describe "Workers" do
      it "gives you the correct number of workers per task" do
        post '/tasks'
        response = last_response.json
        response.each_value.each do |workers|
          workers.length.should == WORKERS_PER_CHUNK
        end
      end 

      it "doesn't assign the foreman to himself" do
        # seed db so a completely filled request must include the foreman
        REDIS.flushdb
        seed_db_with_workers(generate_addrs(11))
        post '/tasks?n=4'
        response = last_response.json
        worker_addrs(response).each do |h|
          h[:addr].should_not == '127.0.0.1'
        end
        # request thus should not have been completely filled
        response.count.should == 3
      end

      it "gives unique workers" do
        post '/tasks?n=4'
        response = last_response.json
        workers = worker_addrs(response).map{ |h| h[:addr] }
        workers.uniq.should == workers
      end

      it "doesn't give timed-out workers" do
        # seed db so a completely filled request must include the timed-out worker
        REDIS.flushdb
        seed_db_with_workers(generate_addrs(11))
        add_worker(generate_addrs(1), 1234, -1)
        post '/tasks?n=4'
        response = last_response.json
        worker_addrs(response).each do |h|
          worker = get_client(h[:addr])
          worker["expiry"].to_i.should > Time.now.to_i 
        end
        # request thus should not have been completely filled
        response.count.should == 3
      end

      it "gives the correct port for workers" do
        post '/tasks?n=4'
        response = last_response.json
        worker_addrs(response).each do |h|
          worker = get_client(h[:addr])
          worker["port"].should == h[:port]
        end
      end
    end
  end
    
  describe "Task completion (DELETE /tasks/:id)" do
    context "when you report a task is correct" do
      before(:each) do
        # create a task
        post '/tasks?n=4'
        @tasks = last_response.json
      end

      it "returns the right key; doesn't return credits; pays workers" do
        @tasks.each_pair do |task_id, workers|
          actual_key = REDIS.hget("tasks:#{task_id}", "key")
          worker_credits = {}
          workers.each do |worker_pair|
            addr, port = worker_pair.split(":")
            worker_credits[addr] = get_client(addr)["credits"].to_i
          end
          delete "/tasks/#{task_id}?valid=1"
          last_response.should be_ok
          response = last_response.json
          response["key"].should == actual_key
          get_client("127.0.0.1")["credits"].to_i.should == 0
          worker_credits.each_pair do |addr, credits|
            (credits + 1).should == get_client(addr)["credits"].to_i
          end
        end
      end

      it "doesn't let you later report it incorrect" do
        @tasks.each_pair do |task_id, workers|
          actual_key = REDIS.hget("tasks:#{task_id}", "key")
          delete "/tasks/#{task_id}"
          last_response.should be_ok
          delete "/tasks/#{task_id}?valid=1"
          last_response.status.should == 404
        end
      end
    end
    
    context "when you report a task is incorrect" do
      before(:each) do
        # create a task
        post '/tasks?n=4'
        @tasks = last_response.json
      end

      it "doesn't return a key; returns your credits; doesn't pay workers" do
        @tasks.each_pair do |task_id, workers|
          actual_key = REDIS.hget("tasks:#{task_id}", "key")
          worker_credits = {}
          workers.each do |worker_pair|
            addr, port = worker_pair.split(":")
            worker_credits[addr] = get_client(addr)["credits"].to_i
          end
          delete "/tasks/#{task_id}"
          last_response.should be_ok
          response = last_response.json
          response["key"].should be_nil
          response["credits"].should be_a(Fixnum)
          worker_credits.each_pair do |addr, credits|
            credits.should == get_client(addr)["credits"].to_i
          end
        end
        get_client("127.0.0.1")["credits"].to_i.should == 12
      end

      it "doesn't let you later report it correct" do
        @tasks.each_pair do |task_id, workers|
          actual_key = REDIS.hget("tasks:#{task_id}", "key")
          delete "/tasks/#{task_id}?valid=1"
          last_response.should be_ok
          delete "/tasks/#{task_id}"
          last_response.status.should == 404
        end
      end
    end

    context "when you report a missing worker" do
      it "assigns credits correctly" do
        post '/tasks'
        task = last_response.json
        task_id = task.keys.first
        worker_addrs = task.values.first.map{|w| w.split(":")[0] }
        missing_worker_addr = worker_addrs.first
        delete "/tasks/#{task_id}?valid=1&missing=#{missing_worker_addr}"

        worker_addrs.each do |addr|
          worker = get_client(addr)
          worker["credits"].to_i.should == NUM_STARTING_CREDITS + 1
          if addr == missing_worker_addr
            worker["tasks_completed"].to_i.should == 0
            worker["tasks_failed"].to_i.should == 1
          else
            worker["tasks_completed"].to_i.should == 1
            worker["tasks_failed"].to_i.should == 0
          end
        end
      end
    end

    context "when the task doesn't exist" do
      it "doesn't let you delete it" do
        delete "/tasks/999"
        last_response.status.should == 404
      end
    end

    context "when yo don't own the task" do
      it "doesn't let you delete" do
        foreman = addrs.shift
        tasks = make_tasks(foreman, addrs.length / WORKERS_PER_CHUNK, addrs)
        tasks.each_pair do |task_id, workers|
          delete "/tasks/#{task_id}"
          last_response.status.should == 404
        end
      end
    end
  end
end
