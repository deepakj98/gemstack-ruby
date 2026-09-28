# Caching

## Application cache

```ruby
GemStack.cache.fetch("product:#{id}", expires_in: 300) { expensive_lookup(id) }
GemStack.cache.fetch([:report, Date.today]) { Report.build }       # array keys
GemStack.cache.fetch(product) { … }                                # records use #cache_key
GemStack.cache.fetch("rates", force: true) { fetch_rates }         # recompute
GemStack.cache.read("k") / write("k", v, expires_in: 60) / delete("k") / exist?("k")
GemStack.cache.increment("signups") / decrement("stock:42", 2)
GemStack.cache.clear
```

`fetch` caches `nil` results too. Values must be `Marshal`-able and are
copied in and out, so mutating a returned value never changes the cache.
Keys are namespaced (`config.cache.namespace`, default: the app name), and
keys longer than 200 bytes are hashed.

`GemStack::Model#cache_key` includes `updated_at`
(`"product/42-1759052159.123456"`), so a key built from a record changes when
the record does.

## Stores

| Store | When | |
|---|---|---|
| `:memory` | default | per-process LRU with expiry (`config.cache.max_entries`, 10,000) |
| `:null` | default in test | never caches, so tests are independent |
| `:redis` | several processes/servers | add `gem "redis-client"`; uses `REDIS_URL` |
| your object | anything else | subclass `GemStack::Cache::Store`, or implement `fetch/read/write/delete/clear` |

```ruby
config.cache.store = :redis
config.cache.redis_url = ENV["REDIS_URL"]
config.cache.default_expires_in = 3600
config.cache.store = MyMemcachedStore.new
```

With Puma workers, the memory store is per worker; use Redis when every
process must see the same entries. The Redis store's `clear` deletes only its
namespace, never the whole database.

Not included (yet): stampede protection, tag-based invalidation.

## HTTP caching

ETags, 304 Not Modified, `stale?` and `cache_control` — see
[performance](performance.md#http-caching) and [controllers](controllers.md#http-caching).
