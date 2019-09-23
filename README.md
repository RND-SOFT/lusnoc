# Lusnoc

[![Gem Version](https://badge.fury.io/rb/lusnoc.svg)](https://rubygems.org/gems/lusnoc)
[![Gem](https://img.shields.io/gem/dt/lusnoc.svg)](https://rubygems.org/gems/lusnoc/versions)


[![Quality](https://lysander.x.rnds.pro/api/v1/badges/lusnoc_quality.svg)](https://lysander.x.rnds.pro/api/v1/badges/lusnoc_quality.html)
[![Outdated](https://lysander.x.rnds.pro/api/v1/badges/lusnoc_outdated.svg)](https://lysander.x.rnds.pro/api/v1/badges/lusnoc_outdated.html)
[![Vulnerabilities](https://lysander.x.rnds.pro/api/v1/badges/lusnoc_vulnerable.svg)](https://lysander.x.rnds.pro/api/v1/badges/lusnoc_vulnerable.html)

Lusnoc is reliable gem to deal with [Consul](https://www.consul.io). It is designed to be simple and work without dark background magic.
It is inspired by [consul-mutex](https://github.com/discourse/consul-mutex)(which has hard background magic). 

## FAQ

#### What's Lusnoc for?

Lusnoc allows you to interact with Consul to provide distributed locks(mutex) to your application.

#### What's the difference between lusnoc and [consul-mutex](https://github.com/discourse/consul-mutex) or [diplomat](https://github.com/WeAreFarmGeek/diplomat)
* consul-mutex starts background thread and  ***the block of code that you pass to #synchronize runs on a separate thread, and can be killed without warning if the mutex determines that it no longer holds the lock.***
* diplomat provides the basic session/locks functionality but no automated control over it

#### How Lusnoc deal with sessions/mutexes?
* Lusnoc ensures session creation/destruction upon block execution
* Lusnoc uses only sessions with TTL to protect you system from stale sessions/locks
* Lusnoc enforces you to manualy renew session(through callback or explicit check) but provide background session checker
* Lusnoc tries to carefuly handle timeouts and expiration using Consul [blocking queries](https://www.consul.io/api/features/blocking.html)

# Usage

Simply instantiate a new `Lusnoc::Mutex`, giving it the key you want to use
as the "lock":

```ruby
  require 'lusnoc/mutex'
  mutex = Lusnoc::Mutex.new('/locks/mx1', ttl: 20)
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
  Lusnoc::Mutex.new('/some/key', value: {time: Time.now}).synchronize do |mx|
    #...
  end
```
Session invalidation/renewal handled through mutex instance:
```ruby
  Lusnoc::Mutex.new('/some/key').synchronize do |mx|
    mx.time_to_expiration # seconds to session expiration in consul. 
    mx.ttl                # session ttl. 
    mx.need_renew?        # true when time_to_expiration less than half of ttl
    
    mx.need_renew?        # false
    sleep (mx.ttl / 2) + 1
    mx.need_renew?        # true
    
    mx.on_mutex_lost do |mutex|
      # this callback will be called from other(guard) thread when mutex is lost(session invalidated)
    end
    
    mx.locked?    # true while session is not expired or invalidated by admin
    mx.owned?     # true while session is not expired or invalidated by admin and owner is a Thread.current
    mx.session_id # id of Consul session
    mx.expired?   # is session expired?
    mx.alive?     # is session alive?
    mx.alive!     # ensures session alive or raise Lusnoc::ExpiredError
    mx.renew      # renew session or raise Lusnoc::ExpiredError if session already expired
  end
```

You can use only Session:
```ruby
  Session.new("session_name", ttl: 20) do |session|
    session.on_session_die do
      # this callback will be called from other(guard) thread when session invalidated
    end

    session.expired?   # is session expired?
    session.alive?     # is session alive?
    session.alive!     # ensures session alive or raise Lusnoc::ExpiredError
    session.renew      # renew session or raise Lusnoc::ExpiredError if session already expired
  end
```
Typical usage scenario:

```ruby
  Lusnoc::Mutex.new('/some/key').synchronize do |mx|
    # do some work
    mx.renew if mx.need_renew?
    # do other work
    mx.renew if mx.need_renew?
    # ...
  rescue Lusnoc::ExpiredError => e
    # Session was invalidated and mutex was lost!
  end
```

# Installation

It's a gem:
```bash
  gem install lusnoc
```
There's also the wonders of [the Gemfile](http://bundler.io):
```ruby
  gem 'lusnoc'
```


