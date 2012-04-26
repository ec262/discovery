EC262 Discovery Server
======================

http://ec262discovery.herokuapp.com

The EC262 Discovery Service matches workers and foreman and keeps track of
credits. Workers register with the service to get assigned jobs and earn
credits for doing work. Foremen request available workers to compute chunks
and pay for the results.


Get up and running locally
--------------------------

The discovery service is written in [Ruby](http://www.ruby-lang.org/)
using the [Sinatra](http://www.sinatrarb.com/) web framework,
[Redis](http://redis.io/) as a datastore, and deployed on Heroku. Ruby 1.9.2
is required; it is recommended that you use [RVM](http://beginrescueend.com/)
to manage your Ruby installations.

Once you have Ruby and Redis installed, you'll probably need to run these
commands. (I'm sure I'm missing some, so let me know what doesn't work.)

1.  `bundle install`
    This installs the required dependencies. You'll need to install bundler
    first by running `gem install bundle` if you have not yet done so. It is
    also recommended that you install the Rake, Foreman, and Heroku gems.

2.  `export REDISTOGO_URL='redis://127.0.0.1:6379'`
    This lets you run Redis locally without fuss. Assumes your Redis server is
    set up to run on 6379, which is the default on Mac OS at least.
    
    
What's in this repo
-------------------

    |-- config.rb               : Configuration code
    |-- discovery.rb            : Application route logic (the web front-end)
    |-- Gemfile                 : Specifies dependencies
    |-- Gemfile.lock            : Complied dependency file (do not edit)
    |-- lib/
    |   |-- chunks.rb           : Application logic related to chunks
    |   |-- exceptions.rb       : Exception definitions (incl. HTTP responses)
    |   |-- json_responder.rb   : Rack middleware to make every response JSON
    |   `-- worker.rb           : Application code related to workers
    |-- Procfile                : Tell Heroku how to run the app
    |-- Rakefile                : Helpful tasks; run `rake -T` to see them all
    |-- README.md               : This file
    `-- spec/
        |-- foreman_api_spec.rb : Tests the Foreman API
        |-- spec_helper.rb      : Setup for the test code 
        `-- worker_api_spec.rb  : Tests the Worker API


How the protocol works
----------------------

1.  Workers register with their address and optionally a port. They start out
    with 12 credits, and can earn more if they do more work. Credit counts
    never reset per address. Registrations last for 1m by default; workers can
    unregister by sending a registration request with a TTL of -1.
    
2.  Foremen request jobs by specifying a number of chunks. If they want _n_
    chunks, they will pay with 3_n_ credits. (If a foreman has never acted as
    a worker, they will start with 12 credits.) The discovery service responds
    with a list of chunks and the workers assigned to them. The discovery
    service tries to respond with workers that are available, but does not
    guarantee it. [1]

3.  By default, workers are single threaded; thus, they will be removed from
    the worker pool once they are assigned a chunk. However, if they wish to
    accept more chunks (or if they simply don't plan on computing the one
    they're given), they can re-register with the discovery service.

4.  The foreman is responsible for sending chunks to workers. Before returning
    their data to the foreman, workers encrypt the results with AES-128 and a
    key assigned by the discovery service. Keys are unique to each chunk. If a
    worker does not wish to participate in a job (or has gone offline), they
    can simply not respond or send garbage back to the foreman.
    
5.  The foreman checks that the encrypted data returned by at least two of the
    workers is valid. If so, the foreman requests the key to decrypt the data
    and the workers receive credits. If not, the foreman tells the discovery
    service and gets the credits back for that chunk, but cannot decrypt the
    data returned by the workers. The foreman can always request more chunks
    from the discovery service.
    
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

        {"1":["worker1:port","worker2:port","worker3:port"],
         "2":["worker4:port", ... ], ... }
          
    If there are not enough available workers, the foreman will only get
    charged for the workers assigned, and can make subsequent requests for
    more workers.
    
          
  - `DELETE /chunks/:id?(valid=1)`
    Tell the discovery server that a chunk computation is valid or has failed.
    If the computation is valid, then the foreman gets a JSON object containing
    the Base64-encoded key associated with the chunk, e.g.
    
        {"key":"Ji8W2byt1Xp83F7K/gKvWg=="}
        
    If the computation failed, the foreman gets 3 credits returned to his
    account and the number of available credits is returned, e.g.
    
        {"credits":12}
    
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
    it returns a JSON object with the requested key, encoded with Base64, e.g.
    
        {"key":"Ji8W2byt1Xp83F7K/gKvWg=="}
        
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

    
Design decisions
----------------

We chose to build on the web stack using Ruby and Sinatra mostly for simplicity
and familiarity. Because nothing in the discovery service is performance
critical, it is feasible to use HTTP. HTTP makes it simple to deploy to a PaaS
like Heroku which presumably has better uptime than any machine we would
administer ourselves. Also, it makes it easy for components written in
different languages (Ruby, Python, and possibly others) to communicate. 

Redis is useful both because it is very fast (all data is stored in memory) and
because its semantics map very well onto our discovery service. Redis instances
are generally persisted by a log that is written to disk. If we were to scale
this system, Redis makes it relatively simple to set up master-slave
replication. We could set up multiple front-ends to process requests, and all
race conditions would be handled by using transactions in Redis and locks at
the application level.

The protocol itself is designed to minimize communication with the discovery
service, and to keep clients from needing to write their own servers that
accept incoming requests from the service. Instead, clients only need to listen
to incoming requests from other clients. We ensure safety in the sense that
foreman only pay (and workers will only get paid) when chunks are fully valid,
though there are risks to liveness which are discussed in the next section.

Leases play an important role in this system. Worker registrations are really
leases, since they automatically expire after a short period. We assume that
workers will frequently go offline and so they must re-register at specified
intervals. Similarly, chunks are merely "leased" to clients; they also expire
after 24h. Individual chunks should not take longer than that to compute, and
there is no reason to continue to keep outdated chunks in memory (since they
will persist in the logs anyway).


Known vulnerabilities
---------------------

  - Foreman can create lots of workers, and try to use those to get keys for
    the data that other people are actually computing on. This would require
    creating a lot of clients with unique addresses.
    
  - An attacker could just generate lots of clients and get lots of credits,
    then generate fake jobs to transfer credits to just one client, who could
    do lots of jobs.
    
  - Workers can just not compute chunks. That would grind things to a halt
    pretty quickly. Similarly, foreman could just requests lots of chunks and
    get refunds for them. [3]
  
  
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
    
3.  In a "live" system, we would be actively collecting statistics about who is
    creating jobs, not doing them, etc. We could then develop heuristics to
    find cheaters who are repeatedly not computing chunks or foremen who are
    creating jobs but not checking them. However, without real usage data, it
    is basically impossible to develop these kinds of counter-measures.


TODO
----
  - You can never have too many tests...
  