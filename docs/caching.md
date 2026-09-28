# Caching

> **Status: planned — Phase 3.**

```ruby
GemStack.cache.fetch("product:#{id}", expires_in: 300) { Product.find(id) }
```

- Stores: in-memory (default in development and test), Redis, Memcached,
  PostgreSQL — `config.cache.store = ...`, or any object with
  `read/write/delete/fetch`. Redis is never required.
- HTTP caching helpers: ETags and conditional GET (`304 Not Modified`).
