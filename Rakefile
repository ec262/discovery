task :server do
  sh "bundle exec shotgun --server=thin --port=5000 discovery.rb"
end

task :console do
  sh "bundle exec irb -r ./config.rb"
end

task :flushdb do
  require './config'
  REDIS.select(0)
  REDIS.flushdb
end

task :seed, [:db, :worker_addr] do |t, args|
  require './config'

  REDIS.select(args.db.to_i || 0)
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

namespace :test do
  task :local do
    sh 'bundle exec rspec'
  end
  
  task :remote do
    require 'socket'
    public_ip = UDPSocket.open {|s| s.connect('64.233.187.99', 1); s.addr.last }
  
    def call_remote  
      def method_missing(*args)
        method, path = args
        if [:get, :post, :delete].index(method)
          sh "\ncurl -w '\\n' -X #{method.to_s.upcase} http://ec262discovery.herokuapp.com#{path}"
        end
      end

      yield
    end
  
    sh "heroku run rake seed[0,#{public_ip}]"
    call_remote do
      get '/chunks/1'
      post '/chunks?n=2'
      get '/'
      delete '/chunks/2?valid=1'
    end
  end
end