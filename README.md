# Lusnoc

Lusnoc is reliable gem to deal with [Consul](https://www.consul.io). It is designed to be simple and without any background magic.
It is inspired by [consul-mutex](https://github.com/discourse/consul-mutex)(which has hard background magic). 

## FAQ

#### What's Lusnoc for?

Lusnoc allows you to interact with Consul to provide distributed locks(mutex) to your application.

#### What's the difference between lusnoc and [consul-mutex](https://github.com/discourse/consul-mutex) or [diplomat](https://github.com/WeAreFarmGeek/diplomat)
* consul-mutex starts background thread and  ***the block of code that you pass to #synchronize runs on a separate thread, and can be killed without warning if the mutex determines that it no longer holds the lock.***
* diplomat provides the basic session/locks functionality but no automated control over it

#### How luscon deal with sessions/mutexes?
* Luscon ensures session creation/destruction upon block execution
* Luscon uses only sessions with TTL to protect you system from stale sessions/locks
* Luscon enforces you to manualy renew session(through callback or explicit check) but provide background session checker
* Luscon tries to carefuly handle timeouts and expiration using Consul [blocking queries](https://www.consul.io/api/features/blocking.html)

# Usage

Simply instantiate a new `Luscon::Mutex`, giving it the key you want to use
as the "lock":

```ruby
  require 'luscon/mutex'
  mutex = Luscon::Mutex.new('/locks/mx1', ttl: 20)
```
TTL will be used in session creation on `#synchronize`:
```ruby
  mutex.synchronize(timeout: 10) do |mx|
    puts "We are exclusively owns resource"
  end
```
If mutex cannot be acquired within given timeout Lusnoc::TimeoutError is raised.
By default, the "value" of the lock resource will be the hostname of the
machine that it's running on (so you know who has the lock).  If, for some
reason, you'd like to set the value to something else, you can do that, too:
```ruby
  Consul::Mutex.new('/some/key', value: {time: Time.now}).synchronize do |mx|
    #...
  end
```
Session invalidation/renewval handled through mutex instance:
```ruby
  Consul::Mutex.new('/some/key').synchronize do |mx|
    mx.time_to_expiration # seconds to session expiration in consul. 
    mx.ttl                # session ttl. 
    mx.need_renew?        # true when time_to_expiration less than half of ttl
    
    mx.on_mutex_lost do |mutex|
      # this callback will be called from other(guard) thread
    end
    
    mx.locked?    # true while session is not expired or invalidated by admin
    mx.owned?     # true while session is not expired or invalidated by admin and owner is a Thread.current
    mx.session_id # id of Consul session
    mx.expired?   # is session expired?
    mx.live?      # is session live?
    mx.live!      # ensures session live or raise exception
    mx.renew      # renew session or raise exception if session already expired
    
  end
```


