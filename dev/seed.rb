require 'dev/console'
require 'lib/worker_api'

REDIS.flushdb

NUM_STARTING_CREDITS = 12

workers = [["127.0.0.1", "2626", "62323"],
           ["1.2.3.4", "2626", "23427"],
           ["example.com", "2334", "8023"],
           ["tom-buckley.com", "3473374", "6202"]]
           
workers.each do |worker|
  addr, port, ttl = worker
  puts "#{addr} #{port} #{ttl.to_i}"
  add_worker(addr, port, ttl)
end