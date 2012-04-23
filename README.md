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

You'll want to run some or all of these commands. (I'm sure I'm missing some, so
let me know what doesn't work.)

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
    Registrations last for 1m by default; workers can unregister by sending a
    registration request with a TTL of -1.
    
2.  Foremen request jobs by specifying a number of chunks. If they want _n_
    chunks, they will pay with 3_n_ credits. (If a foreman has never acted as
    a worker, they will start with 12 credits.) The discovery service responds
    with a list of chunks and the workers assigned to them. The discovery
    service tries to respond with chunks that are available, but does not
    guarantee it. [1]

3.  By default, workers are single threaded; thus, they will be removed from
    the worker pool once they are assigned a chunk. However, if they wish to
    accept more chunks (or if they simply don't plan on computing the one
    they're given), they can re-register with the discovery service.

4.  The foreman is responsible for sending chunks to workers. Workers encrypt
    the data before sending it back to the foreman using a key assigned by the
    discovery service, which is generated for a particular chunk. If a worker
    does not wish to participate in a job (or has gone offline), they can
    simply not respond to the foreman.
    
5.  The foreman checks that the encrypted data returned by at least two of the
    workers is valid. If so, the foreman requests the key to to decrypt the
    data and the workers receive credits. If not, the foreman tells the
    discovery service and gets the credits back for that chunk, but cannot
    decrypt the data returned by the workers. The foreman can always request
    more chunks from the discovery service.
    
6.  Clients can check on the status of a chunk by re-requesting a key; if the
    discovery service has no record of it then the client need not work on
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

        { "1": ["worker1:port", "worker2:port", "worker3:port"],
          "2": ["worker4:port", ...], ... }
          
    If there are not enough available workers, the foreman will only get
    charged for the workers assigned, and can make subsequent requests for
    more workers.
    
          
  - `DELETE /chunks/:id?(valid=1)`
    Tell the discovery server that a chunk computation is valid or has failed.
    If the computation is valid, then the foreman gets a JSON object containing
    the key associated with the chunk, e.g.: 
    
        { "key": "8238539950397531954578546" }
        
    If the computation failed, the foreman gets 3 credits returned to his
    account and the number of available credits is returned, e.g.
    
        { "credits": 12 }
    
    Note that this call is _idempotent_; calling it actually deletes the given
    chunk (to prevent cheating). [2] If the address of the foreman associated
    with that chunk is not used to make this call, or if the chunk does not
    exist, it returns 404 to prevent malicious behavior. Chunks expire after
    24h even if the delete method is not called.
    
          
### Worker API

  - `POST /workers?port=P&ttl=T`
    Register a worker to the worker pool by requesting IP address. Default port
    is 2626. Workers can also specify a time to live in seconds; by default
    registrations last for 1m. Workers should re-register before their TTL
    period expires. Workers can also de-register at any time by setting a TTL
    of -1. Returns a JSON object containing information about the requester.
    
  - `GET /chunks/:id`
    Workers use this to get the key to encrypt their chunk data. If permitted,
    it returns a JSON object with the requested key, e.g.
    
        { "key": "8238539950397531954578546" }
        
    If the chunk does not exist, or the address of the requester is not one of
    the assigned workers, it returns 404.

  - `GET /`
    Returns a JSON object containing info about the requester.


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
        expiry: {t}
        addr: {a}
        
We keep a hash of every individual client by address, prefixed with "clients:".
This way we can quickly get the port and credit count of a client.

### Chunks

    chunks:{id} (hash)
        foreman: {addr}
        workers: [{addr1}, {addr2}, {addr3}]
        key: {k}
        
    chunks
        {id}

Each chunk has its own hash, with fields for the assigned foreman, worker, and
key. Only assigned workers can see the key; only the foreman can destroy the
chunk. Chunks expire after a given interval (for now, 24h). We also keep a
single key, `chunks`, that keeps track of the last chunk created.

### Locks

    lock:chunks:{id}
    
    lock:clients:{id}

Foremen need to be locked when they request chunks, and their accounts are
debited. Chunks need to be locked when foreman request their deletion. We
use the `redis-lock` library to manage these locks.

    
Known vulnerabilities
---------------------

  - Foreman can create lots of workers, and try to use those to get keys for
    the data that other people are actually computing on. This would require
    creating a lot of clients with unique addresses.
    
    
  - An attacker could just generate lots of clients and get lots of credits,
    then generate fake jobs to transfer credits to just one client, who could
    do lots of jobs.
    
  - Workers can just not do jobs. That would grind things to a halt pretty
    quickly. Similarly, foreman could just requests lots of chunks and get
    refunds for them. [3]
 
  
  
Notes
-----

1.  The discovery service _tries_ to return only available workers in the chunk
    list, but may not do so. Workers are automatically removed from the pool
    when a foreman requests them; however, clients may be multi-threaded and
    want to accept multiple chunks at once. In this case, they can re-register
    as soon as they are contacted by a foreman. However we recognize that
    foreman can abuse this system by making requests for clients and not using
    them. (See [3]) Alternatively, we could have left workers registered by
    default; clients could unregister themselves as they become available by
    changing their TTL to -1. In practice, we would have to test the service
    with real users with both settings in order to see how the system responds.
    
2.  Although the client delegation is not thread-safe, all of the methods that
    involve credits are. So foreman cannot cheat by trying to both validate a
    chunk and invalidate it at the same time (in order to get both a refund and
    the key). Also, foreman cannot try to get more workers than they're
    permitted by trying to request chunks in quick succession.
    
3.  In a "live" system of this time, we would be actively collecting statistics
    about who is creating jobs, not doing them, etc. in order to crack down on
    abuse. This would make it easier to find cheaters who are repeatedly
    preventing chunks from finishing, or foremen who are creating jobs but not
    checking them. However, without real usage statistics, it is basically
    impossible to develop these kinds of counter-measures.


TODO
----
  
  - IP vs. host? 
    
  - Test test test, including failure cases
  
  - Proper key generation
  
  