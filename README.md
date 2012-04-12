EC262 Discovery Server, version 0
=================================

http://ec262discovery.herokuapp.com

Workers use the discover service to register themselves so that foremen can
send them jobs; foreman use it to find what workers are available and want
jobs to do.

This app is written in Ruby with Sinatra, backed by Redis, and hosted on
Heroku. The code should pretty much explain itself. 

BEFORE ANYONE USES THIS IN PRODUCTION, let me know and we will clear out the
dummy IP addresses.


Get up and running locally
--------------------------

You'll want to run some or all of these commands--I'm sure I'm missing some, so
let me know what doesn't work.

1. `bundle install`

  This installs all the required gems; you'll need to "`gem install bundle`"
  first if you have not yet done so.

2. `echo "REDISTOGO_URL='redis://127.0.0.1:6379'" > .env`

  This lets you run Redis locally without fuss. Assumes your Redis server is set
up to run on 6379, which is the default on Mac OS at least.


The dead simple API
-------------------

  - `GET /`
    Returns the list of IP addresses of available workers in JSON.

  - `POST /register`
    Register a worker to the worker pool by IP address. Should return status
    code 200 if all goes well.

  
 
TODO
----

  - Before sending back the list of workers, the server should quickly ping
    the workers (or at least the ones it hasn't pinged recently) and make sure
    they're still alive and accepting jobs. Which means that...
    
  - Workers need to keep a port open to accept pings from the discovery server.
    
  - It might also be nice to ask if workers want to accept a job from the
    requester.
    
  - Protected method to remove workers via HTTP.
    
  - Authentication, API keys, etc...