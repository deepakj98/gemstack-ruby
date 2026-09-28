# GemStack Roadmap

GemStack is built incrementally. Each phase must be working, tested and
documented before the next begins.

## Phase 1 — Foundation  *(complete — see "Phase 1 verification" below)*

- [x] Monorepo structure, gems, shared version, lint and test tasks
- [x] Core: settings DSL, environment, `.env` loading, logger, errors, inflector, plugins
- [x] HTTP: request/response, router (`get/post/...`, `resources`, `scope`), route listing
- [x] Middleware stack (use / insert_before / insert_after / swap / delete) with small default stack
- [x] Controllers: `render`, `head`, `before` callbacks, `rescue_from`, params
- [x] JSON codec abstraction (stdlib default, pluggable)
- [x] Consistent JSON error envelope; dev vs production error detail
- [x] Application boot, Zeitwerk autoloading, in-process dev reloading
- [x] CLI: `new`, `dev`, `server`, `routes`, `console`, `generate controller`, `test`, `version`
- [x] Dev gateway: single public origin, WebSocket-aware, friendly "starting" pages
- [x] Process supervisor for Next.js + Ruby API
- [x] Next.js (App Router, TypeScript, TanStack Query) frontend template with vendored API client
- [x] Tests for every package; generated-app smoke test
- [x] Benchmarks for routing, middleware and JSON (docs/performance.md)

### Phase 1 verification

- 172 tests across the five gems, RuboCop clean (`bundle exec rake`).
- `gemstack new` → app with passing Ruby tests and a clean `tsc --noEmit`.
- `gemstack dev`: one public port; `/api/*` served by Puma, pages by Next.js,
  Next.js HMR WebSocket through the gateway (IPv4 + IPv6), in-process reload of
  controllers and routes, API crash reported and auto-recovered on save, clean
  Ctrl-C shutdown.
- Production shape: `next build` + `next start` with rewrites proxying `/api/*`
  to Puma in production mode (JSON logs, no internals in errors).
- Not yet verified in a real browser session; browser behaviour was exercised
  with HTTP/WebSocket clients against the same endpoints.

## Phase 2 — Application layer  *(complete)*

- [x] `gemstack-db`: Sequel integration, PostgreSQL, pool sized to server threads, lazy connect
- [x] `Model` with `field` declarations, validations, associations, transactions
- [x] Migrations + `db:create/drop/migrate/rollback/status/seed/setup/reset`
- [x] Request validation (`accepts` / `input` / `params.validate`) with the standard error envelope
- [x] Database errors mapped to HTTP (404 / 422 field errors / 409 / 503)
- [x] Serializers with typed attributes (inferred from model fields)
- [x] Contract IR + TypeScript types + typed API client + OpenAPI 3.1 (`gemstack contract`)
- [x] Background contract regeneration in `gemstack dev`
- [x] `gemstack generate resource|model|migration` with `--api-only`, `--frontend-only`, `--crud`, `--actions`, interactive mode
- [x] Generated tests for generated resources (transactional, sample data from fields)
- [x] Example application (`examples/shop`) — separate from the app generator

### Phase 2 verification

- 259 tests across eight gems with PostgreSQL available (without it the DB suite skips 18), RuboCop clean. It runs against real
  PostgreSQL when `GEMSTACK_TEST_DATABASE_URL` is set (and skips without it).
- Fresh app: `new` → `generate resource Category …` / `Product …` (7 field types,
  a reference, a unique field) → `db:migrate` → 25 generated tests pass →
  `tsc --noEmit` clean → `next build` succeeds.
- Through the dev gateway: create/list/show/update/delete, 422 field errors,
  unique and foreign-key violations as field errors, 409 for a row still
  referenced, 404 for bad ids; every generated page returns 200; editing a
  serializer regenerated `types.ts` while `gemstack dev` ran.
- `examples/shop`: generated resources plus a custom typed search endpoint,
  seeds and URL-state search UI; 27 tests pass, typecheck and build clean.
- Not yet: pagination for generated `index` actions, interactive generator
  prompts under a real TTY (covered only by code review), browser-level UI tests.

### Ruby 4 and installed-gem distribution

- [x] Minimum Ruby 4.0 (developed on 4.0.7); generated apps pin `.ruby-version` / `.tool-versions`
- [x] `rake gems:build` / `gems:install` / `gems:uninstall`; the installed `gemstack` works like `rails`
- [x] Verified: an app created by the *installed* CLI resolves `gem "gemstack", "~> 0.1.0"` from
      installed gems, runs `generate resource` → `db:migrate` → tests → typecheck → `gemstack dev`
- [ ] Publish to RubyGems.org (claim the `gemstack*` names first — DECISIONS D-031)

## Phase 3 — Performance defaults  *(complete)*

- [x] Compression middleware (Brotli when available, gzip fallback), thresholds, safe skips
- [x] JSON benchmark (stdlib vs reworked Oj) → stdlib stays default (D-037)
- [x] Router / middleware / serialization / compression / cache benchmarks, allocation counts
- [x] Serializer optimisation from profiling evidence (3× faster, D-038)
- [x] Caching foundations: `GemStack.cache`, memory / null / Redis stores (`gemstack-cache`)
- [x] ETags / conditional GET (Rack) + `stale?` / `fresh_when` / `cache_control`
- [x] Pagination convention for `index` actions, typed `Paginated<T>` in the contract, pager in generated pages
- [x] Production review: YJIT by default (`config.jit`), compression levels, DB pool per thread
- [x] End-to-end server benchmark (`benchmarks/server_bench.sh`)

### Phase 3 verification

- 304 tests across nine gems with PostgreSQL and Redis available (0 skipped); RuboCop clean.
- Real Redis (`GEMSTACK_TEST_REDIS_URL`) and real PostgreSQL runs of the cache and DB suites.
- `examples/shop` through the dev gateway: `{data, meta}` pages and `?page=` pager, 422 for
  invalid pages, gzip-encoded responses with `Vary` and weak ETags, 304 on revalidation.
- Not yet: cache stampede protection, keyset pagination, streaming compression for large
  bodies of unknown length, database benchmarks.

## Phase 4 — Background processing  *(complete)*

- [x] `GemStack::Job` API: queue, priority, retry_on, discard_on, perform_later, set(wait:/at:), perform_now
- [x] Adapters: postgres (default), async, inline, test, sidekiq — one shared executor
- [x] PostgreSQL queue: transactional enqueue, SKIP LOCKED claiming, LISTEN/NOTIFY wake-up, polling fallback
- [x] Retries with exponential backoff, discards, failed set, stale-lock recovery, graceful shutdown
- [x] `gemstack jobs`, `jobs:status`, `jobs:failed`, `jobs:retry`, `jobs:discard`, `jobs:install`
- [x] `generate job` (adds the table migration the first time); worker in `gemstack dev`
- [x] Structured job logs + `GemStack::Jobs.subscribe` events; test helpers
- [x] Example app: background announcement job, enqueued transactionally

### Phase 4 verification

- 349 tests across ten gems, 0 skipped with PostgreSQL + Redis; RuboCop clean.
- Jobs suite against real PostgreSQL and Redis (Sidekiq bridge): transactional enqueue,
  priority/run_at ordering, 4 concurrent workers claiming 20 jobs exactly once, NOTIFY latency,
  retry/fail/discard settlement, stale-lock release, graceful shutdown.
- Fresh app via the installed gems: `generate job`, enqueue inside `GemStack.transaction`,
  worker started by `gemstack dev` ran the job 3 ms after the request committed.
- Found and fixed: Sequel's JSONB parsing broken on json 3 (D-041), buffered log output (D-042),
  duplicate migration timestamps, name collisions (`Digest`, `Page`) and a form typing bug (D-043).
- `script/e2e`: generated app with every field type + edge cases → 65 generated tests, `tsc`, `next build` pass.
- Not yet: recurring (cron) jobs, unique jobs, batches, a web dashboard.

## Phase 5 — Realtime

- [ ] `GemStack.broadcast` + channel authorisation
- [ ] SSE transport (default) and WebSocket transport adapter
- [ ] Broker adapters: Postgres LISTEN/NOTIFY (default), Redis
- [ ] TypeScript `realtime.subscribe` client with reconnect / replay

## Phase 6 — Optional modules

- [ ] `gemstack add auth` (sessions and tokens, bcrypt/argon2 via gems)
- [ ] Authorization policies
- [ ] Mail, storage (local / S3), additional cache adapters

## Phase 7 — Developer experience

- [ ] Richer development error pages, `gemstack doctor`
- [ ] OpenAPI documentation UI
- [ ] Deployment recipes (Docker, Caddy, Fly/Render/Railway)
- [ ] Published npm package for the client runtime (optional to the vendored one)
