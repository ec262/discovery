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
  puts chunks.inspect
end

def get_public_ip
  require 'socket'
  puts UDPSocket.open {|s| s.connect('64.233.187.99', 1); s.addr.last }
end

def hash_to_url_params(h)
  str = "?"
  hash.each_pair do |k, v|
    str.append("#{k}=#{v}&")
  end
  str.chop
end

def get(path, remote="http://ec262discovery.herokuapp.com/")
  require 'net/http'
  puts "GET #{remote + path + hash_to_url_params(params)} "
  puts Net::HTTP.get(URI(remote + path))
end

def post(path, params, remote="http://ec262.herokuapp.com/")
  require 'net/http'
  puts "POST #{remote + path} #{remote + path + hash_to_url_params(params)} "
  Net::HTTP.post_form(URI(remote + path), params)
end

def delete(path, remote="http://ec262.herokuapp.com/")
  require 'net/http'
  puts "DELETE #{remote + path} #{remote + path} "
  Net::HTTP.delete(URI(remote + path))
end


task :test_remote do |t, args|
    sh "heroku run rake seed[0,#{get_public_ip}]"
    get "/chunks/1"
    post "/chunks", :n => 2 
    get "/"
    delete "/chunks/2?valid=1"
end

task :server do
  sh "bundle exec shotgun --server=thin --port=5000 discovery.rb"
end

task :test do
  sh "rspec"
end