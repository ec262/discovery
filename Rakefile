desc "Run a server with shotgun (automatically restarts when you save a new file)"
task :server do
  sh "bundle exec shotgun --server=thin --port=5000 discovery.rb"
end

desc "Starts an irb session with a loaded environment"
task :console do
  sh "bundle exec irb -r ./config.rb"
end

desc "Clears the database"
task :flushdb do
  require './config'
  REDIS.select(0)
  REDIS.flushdb
end

desc "Seeds the database; takes optional paramters for which database and a worker address to add"
task :seed, [:db, :worker_addr] do |t, args|
  require './config'

  REDIS.select(args.db.to_i || 0)
  REDIS.flushdb
  
  seed_db(args.worker_addr)
end

namespace :test do
  desc "Runs full local test suite"
  task :local do
    sh 'bundle exec rspec'
  end
  
  desc "Runs some basic tests to make sure Heroku is working"
  task :remote do
    require 'socket'
    public_ip = UDPSocket.open {|s| s.connect('64.233.187.99', 1); s.addr.last }
  
    # Mini DSL to make HTTP requests from the shell
    def call_remote  
      def method_missing(*args)
        method, path = args
        if [:get, :post, :delete].index(method)
          sh "\ncurl -w '\\n' -X #{method.to_s.upcase} http://ec262discovery.herokuapp.com#{path}"
        end
      end

      yield
    end
  
    # sh "heroku run rake seed[0,#{public_ip}]"
    call_remote do
      get '/seed'
      get '/tasks/1'
      post '/tasks?n=2'
      get '/'
      delete '/tasks/2?valid=1'
    end
  end
end