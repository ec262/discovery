EC262 Discovery Server, version 0
=================================

http://ec262discovery.herokuapp.com

Workers use the discover service to register themselves so that foremen can
send them jobs; foreman use it to find what workers are available and want
jobs to do.

This app is written in Ruby with Sinatra, backed by Redis, and hosted on
Heroku. The code should pretty much explain itself. 



Get up and running locally
--------------------------

You'll want to run some or all of these commands--I'm sure I'm missing some, so
let me know what doesn't work.

1. `bundle install`
  This installs all the required gems; you'll need to "`gem install bundle`"
  first if you have not yet done so.

2. `echo "REDISTOGO_URL='redis://127.0.0.1:6379'" > .env`
  This lets you run Redis locally without fuss. Assumes your Redis server is
  set up to run on 6379, which is the default on Mac OS at least.


How the protocol works
----------------------

1.  Workers register with their address and a port (or with their own address
    and default port if none is given). They start out with 12 credits, and can
    earn more if they do more work. Credit counts never reset per hostname. 
    Registrations last for 1hr by default; workers can also remove registers.
    
2.  Foremen request jobs by specifying a number of chunks. If they want _n_
    chunks, they will pay with 3_n_ credits. (If a foreman has never acted as
    a worker, they will start with 12 credits.) The discovery service responds
    with a list of chunks and the workers assigned to them.

3.  The foreman are now responsible for assigning chunks to workers. Workers
    will encrypt the data before they send it back to the foreman using a key
    given to them by the discovery service, which is generated for that
    particular chunk of that particular job. If a worker does not wish to
    participate in a job (or has simply gone offline), they can simply not
    respond to the foreman.
    
4.  The foreman check that the encrypted data returned by at least two of the
    workers is valid. If so, the foreman requests the key to to decrypt the
    data. If not, the foreman tells the discovery service and gets the credits
    back for that chunk, but cannot encrypt the data returned by the workers.
    If the chunk failed, the foreman can request more chunks from the discovery
    service.


The REST API
------------

# Foreman API

  - `POST /chunks?n=N`
    Get a list of chunks and associated workers. Foremen can specify the number
    of chunks they want (1 by default). Chunks cost 3 credits each. If the
    foreman does not have sufficient credits, the call fails with status code
    406 (not acceptable).
    
    If the call is successful, the server returns status code 200 and a JSON
    object with keys corresponding to chunk IDs, and each key containing an
    array of the three workers that are assigned to that chunk, e.g.
        { chunk1: [worker1, worker2, worker4],
          chunk2: [worker5, worker3, worker7] }
          
  - `PUT /chunks/:id?valid=(true|false)`
    Tell the discovery server that a chunk computation is valid or has failed.
    With invalid or no parameters, assume the computation failed. If the
    computation is valid, then the foreman gets the key associated with
    the chunk. If the computation failed, the foreman gets 3 credits returned
    to his account. Note that this call is _idempotent_; foreman may not use it
    twice to get both the key and credits returned. If the address of the
    foreman associated with that chunk is not used to make this call, it
    returns 403 (forbidden).
          
# Worker API

  - `POST /workers?addr=A&port=P&ttl=T`
    Register a worker to the worker pool by address and port. If no address
    given, register the address of the requester. Default port is 2626. Workers
    can also specify a time to live in minutes; by default registrations last
    for 1hr. Returns status code 200 if all goes well.
    
  - `GET /chunks/:id`
    Workers use this to get the key to encrypt their chunk data. Returns 200 if
    the worker is in fact assigned to that chunk. If the address of the
    foreman associated with that chunk is not used to make this call, it
    returns 403 (forbidden).

# Developer API

**These methods are provided for development purposes only and will probably be
removed in future versions.**

  - `DELETE /workers/(:addr)` 
    Delete a worker with the given address (or the address of the requester).
    Does not remove information about credits; otherwise foremen could just
    keep deleting their account and run 12-credit jobs.

  - `GET /workers/(:addr)`
    Returns internal DB state relating to the requested worker.
    
    
Known vulnerabilities
---------------------

  - Foreman can create lots of workers, and try to use those to get keys for
    the data that other people are actually computing on. This would require
    creating a lot of clients with unique addresses
    
  - Workers can just not do jobs. That would grind things to a halt pretty
    quickly.
  
  - An attacker could just generate lots of clients and get lots of credits,
    then generate fake jobs to transfer credits to just one client, who could
    do lots of jobs.
  
 
TODO
----

  - Authentication! Don't just let anyone do this stuff.
  
  - Before sending back the list of workers, the server should quickly ping
    the workers (or at least the ones it hasn't pinged recently) and make sure
    they're still alive and accepting jobs. Which means that...
    
  - Workers need to keep a port open to accept pings from the discovery server.
    
  - It might also be nice to ask if workers want to accept a job from the
    requester.
    
  - TESTING: check failure cases as well
  