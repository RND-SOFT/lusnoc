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
* Luscon enforces you to manualy renew session(through callback or explicit check) but provide background session checker
* Luscon tries to carefuly handle timeouts and expiration using Consul [blocking queries](https://www.consul.io/api/features/blocking.html)
