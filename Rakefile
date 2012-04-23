task :console do
  sh "bundle exec irb -r config.rb"
end

task :flushdb do
  require './config'
  REDIS.select(0)
  REDIS.flushdb
end

task :seed, [:db, :worker_addr] do |t, args|
  require './config'

  REDIS.select(args.db || 0)
  REDIS.flushdb

  # Basic seeding of workers
  addrs = generate_addrs(20)
  seed_db_with_workers(addrs)
  add_worker(args.worker_addr, nil, nil)

  # Create a chunk with a given worker
  chunk_workers = addrs.take(2).push(args.worker_addr || "127.0.0.1")
  chunks = make_chunks(addrs.last, chunk_workers)
  puts "Created chunks " + chunks.inspect
end

def get_public_ip
  require 'socket'
  UDPSocket.open {|s| s.connect('64.233.187.99', 1); s.addr.last }
end


def call_remote  
  def hash_to_url_params(h)
    str = ""
    h.each_pair do |k, v|
      str += "#{k}=#{v}&"
    end
    str.chop
  end

  def curl(method, path, params=nil, host="http://ec262discovery.herokuapp.com")
    command = "curl -X #{method.to_s.upcase} #{host + path}"
    command += " -d #{hash_to_url_params(params)}" if params
    sh command
    puts
  end
  
  def method_missing(*args)
    if [:get, :post, :delete].index(args[0])
      puts
      curl(*args)
    end
  end
  
  yield
end

task :test_remote do |t, args|
  sh "heroku run rake seed[0,#{get_public_ip}]"
  call_remote do
    get '/chunks/1'
    post '/chunks', :n => 2
    get '/'
    delete '/chunks/2?valid=1'
  end
end

task :server do
  sh "bundle exec shotgun --server=thin --port=5000 discovery.rb"
end

task :test do
  sh "rspec"
end