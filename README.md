EC262 Discovery Server
======================

http://ec262discovery.herokuapp.com

The EC262 Discovery Service matches workers and foreman and keeps track of
credits. Workers register with the service to get assigned jobs and earn
credits for doing work. Foremen request available workers to compute chunks
and pay for the results.

The service is written in Ruby with Sinatra, backed by Redis, and hosted on
Heroku.


Get up and running locally
--------------------------

You'll want to run some or all of these commands--I'm sure I'm missing some, so
let me know what doesn't work.

1.  `bundle install`
    This installs all the required gems; you'll need to `gem install bundle`
    first if you have not yet done so.

2.  `export REDISTOGO_URL='redis://127.0.0.1:6379'`
    This lets you run Redis locally without fuss. Assumes your Redis server is
    set up to run on 6379, which is the default on Mac OS at least.


How the protocol works
----------------------

1.  Workers register with their address and a port (or with their own address
    and default port if none is given). They start out with 12 credits, and can
    earn more if they do more work. Credit counts never reset per address. 
    Registrations last for 1m by default; workers can also remove registers.
    
2.  Foremen request jobs by specifying a number of chunks. If they want _n_
    chunks, they will pay with 3_n_ credits. (If a foreman has never acted as
    a worker, they will start with 12 credits.) The discovery service responds
    with a list of chunks and the workers assigned to them. The discovery
    service tries to respond with chunks that are available, but if not

3.  By default, workers are single threaded; thus, they will be removed from
    the worker pool once they are assigned a chunk. However, if they wish to
    accept more chunks (or if they simply don't plan on computing the one
    they're given), they can re-register with the discovery service.

4.  The foreman is responsible for sending chunks to workers. Workers encrypt
    the data before sending it back to the foreman using a key assigned by the
    discovery service, which is generated for a particular chunk. If a worker
    does not wish to participate in a job (or has simply gone offline), they
    can simply not respond to the foreman.
    
5.  The foreman check that the encrypted data returned by at least two of the
    workers is valid. If so, the foreman requests the key to to decrypt the
    data. If not, the foreman tells the discovery service and gets the credits
    back for that chunk, but cannot encrypt the data returned by the workers.
    If the chunk failed, the foreman can request more chunks from the discovery
    service.
    
6.  Clients can check on the status of a chunk by again requesting a key; if
    the discovery service has no record of it then the client need not work on
    the chunk.


The REST API
------------

### Foreman API

  - `POST /chunks?n=N`
    Get a list of chunks and associated workers. Foremen can specify the number
    of chunks they want (1 by default). Chunks cost 3 credits each. If the
    foreman does not have sufficient credits, the call fails with status code
    406 (not acceptable).
    
    If the call is successful, the server returns status code 200 and a JSON
    object with keys corresponding to chunk IDs, and each key containing an
    array of the three workers that are assigned to that chunk, e.g.

        { chunk1: [worker1, worker2:port, worker4],
          chunk2: [worker5, worker3, worker7:port] }
          
    If there are not enough available workers, the foreman will only get
    charged for the workers assigned, and can make subsequent requests for
    more workers.
    
          
  - `DELETE /chunks/:id?(valid=1)`
    Tell the discovery server that a chunk computation is valid or has failed.
    If the computation is valid, then the foreman gets the key associated with
    the chunk. If the computation failed, the foreman gets 3 credits returned
    to his account and the number of available credits is returned. Note that
    this call is _idempotent_; calling it actually deletes the given chunk (to
    prevent cheating). If the address of the foreman associated with that chunk
    is not used to make this call, it returns 403 (forbidden). Chunks expire
    after 24h even if the delete method is not called.
          
### Worker API

  - `POST /workers?addr=A&port=P&ttl=T`
    Register a worker to the worker pool by address and port. If no address
    given, register the address of the requester. Default port is 2626. Workers
    can also specify a time to live in seconds; by default registrations last
    for 1m. Returns status code 200 if all goes well.
    
  - `GET /chunks/:id`
    Workers use this to get the key to encrypt their chunk data. Returns 200 if
    the worker is in fact assigned to that chunk. If the address of the
    foreman associated with that chunk is not used to make this call, it
    returns 403 (forbidden).

### Developer API

**These methods are provided for development purposes only and will probably be
removed in future versions.**

  - `GET /workers`
    Returns the current set of workers.
  
  - `GET /workers/:addr`
    Returns internal DB state relating to the requested worker.

  - `DELETE /workers/(:addr)` 
    Delete a worker with the given address (or the address of the requester).
    Does not remove information about credits; otherwise foremen could just
    keep deleting their account and run 12-credit jobs.


Redis Schema
------------

Of course Redis doesn't really have schema, but it's worth considering how
Redis is organized to store stuff:

### Worker pool

    workers (sorted set)
        {(addr, expiry), ...}
 
We keep a sorted set of all the workers and their expiries. This lets us easily
grab as many available workers as we need.
       
### Clients

    clients:{addr} (hash)
        port: {p}
        credits: {c}
        
We keep a hash of every individual client by address, prefixed with "clients:".
This way we can quickly get the port and credit count of a client.

### Chunks

    chunks:{id} (hash)
        foreman: {addr}
        workers: [{addr1}, {addr2}, {addr3}]
        key: {k}

Each chunk has its own hash, with fields for the assigned foreman, worker, and
key. Only assigned workers can see the key; only the foreman can destroy the
chunk. Chunks expire after a given interval (for now, 24h).

    
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
  
  - IP vs. host? 
    
  - Test test test, including failure cases
  
  - Proper key generation
  
  - Figure out TTLs
  