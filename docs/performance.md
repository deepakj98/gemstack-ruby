# Performance

GemStack's rule: design so the default path is cheap, then **measure** before
optimising anything else.

## What's fast by construction

- **Compiled middleware** — the stack is built once at boot into nested Rack
  apps; nothing is assembled per request.
- **Small default stack** — seven middlewares, each a few lines.
- **Router** — fully static paths are one hash lookup; dynamic paths walk a
  segment trie whose cost depends on path depth, not route count. Controller
  constants are resolved once.
- **Lazy bodies** — request bodies are read and parsed only if `params` or
  `request.json` is used.
- **C-backed JSON** — the default codec uses `JSON::Coder`; Ruby code runs only
  for non-native objects.
- **Puma** with threads (and workers + `preload_app!` via `WEB_CONCURRENCY`),
  eager loading in production.

## Measurements

`bundle exec rake bench` (script: `benchmarks/request_bench.rb`). In-process,
no network; the request figures include building the Rack env.

Ruby 3.2.2 (no YJIT), json 2.18, Apple Silicon laptop, 602 routes:

| Benchmark | µs/op | ops/s | allocations/op |
|---|---:|---:|---:|
| router: static path | 0.35 | 2.85 M | 4 |
| router: dynamic path (`/products/:id`) | 2.3 | 440 k | 22 |
| router: miss | 2.3 | 450 k | 19 |
| request: health check (middleware only) | 7.3 | 137 k | 45 |
| request: show, no middleware | 11.2 | 89 k | 62 |
| request: show, **default middleware** | 15.6 | 64 k | 79 |
| request: index (20 records), default stack | 13.4 | 74 k | 54 |
| JSON dump, 20 records — stdlib codec | 3.5 | 285 k | 1 |
| JSON dump, 20 records — Oj codec | 25.6 | 39 k | 183 |

Reading the numbers:

- The whole default middleware stack costs ≈ 4 µs per request.
- Framework overhead for a typical endpoint is ≈ 15 µs — small next to a
  single database query.
- The stdlib codec is the right default (DECISIONS D-006). The Oj codec is slow
  **because of GemStack's adapter**, which normalises values in Ruby before
  calling Oj — this is not a verdict on Oj. Phase 3 will rework that adapter
  and re-measure before any default changes.
- Dynamic routes allocate 22 objects (segment splitting and decoding): a known,
  cheap-enough cost, to be revisited only if profiling shows it matters.

## Planned (Phase 3)

Compression (Brotli/gzip negotiation), ETags / conditional GET, caching,
database pool sizing, and end-to-end benchmarks through Puma with realistic
payloads. Results will be added here.

## In development

The dev gateway opens one upstream connection per request (see DECISIONS
D-008). That costs ~0.1 ms on localhost and does not exist in production.
