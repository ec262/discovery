task :console do
  sh "bundle exec irb -r config.rb"
end

task :seed do
  require 'config'

  REDIS.flushdb

  workers = [["127.0.0.1", "2626", "62323"],
             ["1.2.3.4", "2626", "23427"],
             ["example.com", "2334", "8023"],
             ["tom-buckley.com", "3473374", "6202"]]

  workers.each do |worker|
    addr, port, ttl = worker
    puts "#{addr} #{port} #{ttl.to_i}"
    add_worker(addr, port, ttl)
  end
end

task :server do
  sh "bundle exec shotgun --server=thin --port=5000 discovery.rb"
end

task :test do
  sh "rspec"
end