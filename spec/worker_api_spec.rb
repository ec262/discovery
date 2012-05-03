require './spec/spec_helper'
  
describe 'Worker API' do
  
  def app
    Sinatra::Application
  end

  before(:each) do
    REDIS.flushdb
  end

  describe "Registration (POST /workers)" do
    context "when not previously registrated" do
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
      
      it "adds correct TTLs and ports" do
        t = Time.now.to_i
        post "/workers", params={:ttl=>20, :port=>8302}
        worker = get_client("127.0.0.1")
        worker["expiry"].to_i.should == t + 20
        worker["port"].to_i.should == 8302
      end
      
      it 'gives you some credits' do
        post "/workers"
        worker = get_client("127.0.0.1")
        worker["credits"].to_i.should == NUM_STARTING_CREDITS
      end
    end

    context "when already registered" do
      before(:each) do
        post "/workers"
        worker = get_client("127.0.0.1")
      end

      it "allows you to re-register" do
        post "/workers"
        last_response.should be_ok
        worker = last_response.json
        worker["addr"].should == "127.0.0.1"
      end

      it "updates correct TTLs and ports" do
        t = Time.now.to_i
        post "/workers", params={:ttl=>20, :port=>8302}
        worker = get_client("127.0.0.1")
        worker["expiry"].to_i.should == t + 20
        worker["port"].to_i.should == 8302
      end

      it "doesn't give you more credits" do
        post "/workers"
        worker = get_client("127.0.0.1")
        worker["credits"].to_i.should == NUM_STARTING_CREDITS
      end
      
      it "doesn't reset your credits" do
        # change credits
        REDIS.hmset("clients:127.0.0.1", "credits", 50)
        # register again
        post "/workers", params={:port=>1234}
        worker = get_client("127.0.0.1")
        worker["credits"].to_i.should == 50
        # ensure we've actually checked the correct worker
        worker["port"].to_i.should == 1234
      end
    end
  end


  describe "Task keys (GET /tasks/:id)" do
    context "when assigned to the task" do
      it "returns the correct key" do
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
    end
    
    context "when not assigned to the task" do
      it "doesn't return a key" do
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
  end

end  
