require 'spec_helper'

describe 'Foreman API' do
  
  def app
    Sinatra::Application
  end
  
  addrs = []

  before(:each) do
    REDIS.flushdb
    addrs = ["127.0.0.1", "example.com", "tom-buckley.com"]
    seed_db_with_workers(addrs)
  end
  
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
  
  it "doesn't let you delete non-existent chunks" do
  end
end