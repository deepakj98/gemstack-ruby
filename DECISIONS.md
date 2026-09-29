# Architectural Decision Log

Each entry: context, decision, reasoning, consequences. Entries marked
**Proposed** are designs for future phases that will be confirmed (or revised)
when that phase is implemented.

---

## D-001 Build on Rack 3

**Context.** GemStack needs an HTTP interface between servers and the framework.

**Decision.** GemStack's HTTP application is a Rack 3 application.

**Reasoning.** Rack is the Ruby standard. It gives us every production server
(Puma, Falcon, Unicorn, Pitchfork) for free, and lets developers drop in any
existing Rack middleware (`rack-attack`, `rack-cors`, OpenTelemetry, Sentry).
Writing our own server interface would isolate GemStack from the ecosystem —
explicitly against the brief. Rack 3's overhead is a hash and a triple.

**Consequences.** `GemStack.application` is callable with `call(env)`. We keep
our own `Request`/`Response` objects thin wrappers over the env.

## D-002 Puma as the default server

**Decision.** Generated apps use Puma, configured by `config/puma.rb` with
threads/workers from ENV.

**Reasoning.** Mature, maintained, threaded + clustered, the de-facto Ruby
default, good performance for I/O-bound API work. Any other Rack server works
unchanged via `config.ru`. Falcon will be evaluated for realtime (Phase 5).

## D-003 Monorepo of small gems with a zero-dependency core

**Decision.** Gems: `gemstack-core`, `gemstack-http`, `gemstack-dev`,
`gemstack-cli`, and the umbrella `gemstack`. Future modules are separate gems.
All share one version (`VERSION` file).

**Reasoning.** Enforces the rule "core never depends on optional modules"
structurally: a gemspec cannot accidentally require something it does not
declare. Separate gems let users drop pieces (e.g. use `gemstack-http` alone).
A single version avoids compatibility matrices. We did *not* split router,
controller, JSON and middleware into separate gems: they change together, have
no independent users yet, and more gems would add ceremony without benefit.
They are separate namespaces inside `gemstack-http` and can be split later.

## D-004 Our own router

**Context.** Options: Mustermann-based matching, Rails' Journey, a minimal
custom router.

**Decision.** A small custom router: static routes in a hash, dynamic routes in
a per-verb segment trie, `:param` and trailing `*glob` segments.

**Reasoning.** The routing needs of a JSON API are simple (no format suffixes,
no optional segments). A trie gives O(path depth) matching regardless of the
number of routes, and static lookups are O(1). The whole router is ~200 lines,
fully testable, and exposes the route table as data — which the TypeScript/
OpenAPI generators need. Mustermann is not a dependency we can justify for
this.

**Consequences.** No regex constraints in Phase 1 (can be added as a
per-segment matcher if needed).

## D-005 Routes are declared relative to `api_path`

**Decision.** `config/routes.rb` declares `get "/products"`, which serves
`/api/products`. `config.http.api_path` (default `/api`) is the prefix, and it
is also what the gateway uses to route requests to Ruby.

**Reasoning.** One setting controls both where the API lives and how traffic
is split, so they cannot disagree (DRY). The full paths are shown by
`gemstack routes`. The prefix is *not* stripped anywhere: requests keep their
real path end to end, which keeps logs, proxies and separate-domain setups
unambiguous. Set `api_path = ""` for a root-mounted API on its own domain.

## D-006 JSON codec: stdlib `json` by default, pluggable

**Decision.** `config.http.json` defaults to a codec backed by the `json` gem;
an `Oj` codec is included and selected with `config.http.json = :oj`.

**Reasoning.** `json` ≥ 2.10 closed most of the historical gap with Oj,
ships with Ruby, has no native-extension install risk and is always present.
The codec interface (`dump`, `load`) means switching is one line. Phase 3 will
benchmark both on realistic payloads and revisit the default with evidence.

## D-007 Zeitwerk for autoloading and reloading

**Decision.** `app/*` directories are managed by Zeitwerk. In development,
a reloader middleware checks file mtimes and reloads code + routes before the
next request.

**Reasoning.** Zeitwerk is the mature standard (used by Rails, Hanami), has
no transitive dependencies, and supports eager loading in production. Reloading
in-process is much faster than restarting Puma. A read/write interlock makes
reloading safe with Puma's threads: requests hold a shared lock; a reload takes
the exclusive lock.

**Consequences.** Standard Zeitwerk naming conventions apply
(`app/controllers/products_controller.rb` → `ProductsController`). Changes in
`config/` other than routes restart the API process (the supervisor handles it).

## D-008 Dev gateway in Ruby, proxying at the byte level

**Context.** The brief requires one public dev origin. Options:
(a) Next.js `rewrites` only, (b) a Node proxy (`http-proxy`),
(c) Ruby app on the public port proxying to Next.js, (d) a standalone Ruby
gateway process.

**Decision.** (d): a small threaded TCP gateway in `gemstack-dev`. It parses
only the request line and headers, chooses the upstream by path, and then
copies bytes in both directions. Upstream connections are per request
(`Connection: close`).

**Reasoning.**
- (a) Next rewrites do not proxy WebSocket upgrades to external targets, and
  the Next dev server boots slowly — there is no good "API is still starting"
  experience, and `/api` stops working whenever Next.js crashes.
- (b) adds a Node dependency to the Ruby side of the toolchain.
- (c) makes Ruby responsible for proxying Next.js HMR through Puma threads
  and couples API restarts to frontend availability.
- (d) is independent of both processes, understands nothing it doesn't need
  to, and byte-level piping makes SSE, streaming and WebSockets work with no
  special cases. Per-request upstream connections avoid needing to parse
  response framing to support keep-alive — a dev-only trade-off with negligible
  cost on localhost.

**Consequences.** The gateway is not intended for production. Production uses
a real reverse proxy or the generated Next.js rewrites (see D-010).

## D-009 Vendored TypeScript client runtime

**Decision.** `gemstack new` writes the client runtime into
`frontend/lib/gemstack/` instead of depending on an npm package.

**Reasoning.** GemStack is not published to npm yet; a vendored file of ~100
lines is transparent, has no install step and can be customised by the app
(interceptors, auth headers) — consistent with "smart defaults, not rigid
defaults". Generated per-resource clients (Phase 2) import from it.

**Consequences.** Upgrading the runtime is a regeneration step
(`gemstack update client`, Phase 7). A published package may be offered later
as an alternative.

## D-010 Production single-origin via Next.js rewrites or a reverse proxy

**Decision.** The generated `next.config.ts` rewrites `/api/:path*` to
`GEMSTACK_API_URL` (only when that variable is set). The documented preferred
production shape is a reverse proxy routing `/api/*` to Puma.

**Reasoning.** Rewrites give a working single-origin deployment on any Next.js
host with zero extra infrastructure; the reverse proxy is better for
WebSockets and avoids a hop through Node for API traffic. Both keep the browser
on relative `/api` URLs, so frontend code is identical across dev and prod.

## D-011 Server-side API calls use `GEMSTACK_API_URL`

**Decision.** In Server Components the vendored client prefixes requests with
`GEMSTACK_API_URL` (set automatically by `gemstack dev`, set by the deployer in
production); in the browser it uses relative URLs.

**Reasoning.** Relative URLs have no meaning on the server. Calling Ruby
directly from the Next.js server skips the gateway/proxy hop.

## D-012 Frontend state: TanStack Query + React state, no Redux

**Decision.** The template installs `@tanstack/react-query` with a
`QueryClientProvider` in `app/providers.tsx`. Nothing else.

**Reasoning.** Server state is the dominant state in API-backed apps and
TanStack Query is the mature solution. Local state is React state; URL state
is Next.js search params. GemStack adds no state library of its own.

## D-013 Minimal `.env` loader in core

**Decision.** Core loads `.env` and `.env.<env>` (never overriding real ENV
variables) with a ~40-line parser, in development and test only by default.

**Reasoning.** Needed so zero-config dev works. `dotenv` is fine but core is
dependency-free by rule; the format we support (KEY=VALUE, quotes, comments,
`export`) is small. Apps can add `dotenv` and disable ours
(`config.env_files = []`). Production secrets come from the real environment.

## D-014 Thor for the CLI

**Decision.** `gemstack-cli` uses Thor for command parsing and file
generation.

**Reasoning.** Mature, stable, already present in most Ruby environments, and
provides templates, conflict prompts and colour output that generators need.
Writing an option parser + generator toolkit ourselves has no benefit.

## D-015 Error envelope

**Decision.** Every error response is
`{"error": {"code", "message", "request_id"}, "errors"?: {field: [messages]}}`.

**Reasoning.** A single, machine-readable `code` lets frontend code branch on
errors without parsing messages; `errors` is the conventional validation shape
from the brief; `request_id` ties user reports to logs. The TypeScript client
turns this into a typed `ApiError`.

## D-016 Health endpoint is infrastructure, not a resource

**Decision.** `GET <api_path>/health` is answered by a removable middleware.

**Reasoning.** Load balancers and the starter page both need a liveness check;
it is not business functionality, so it doesn't violate "no default resources".
`config.http.health_path = nil` disables it.

## D-017 Findings recorded during Phase 1 verification

- **Next.js rewrites are fixed at build time.** `rewrites()` runs during
  `next build`, so `GEMSTACK_API_URL` must be set when building for the
  rewrite-based deployment (docs/deployment.md says so prominently).
- **Next.js 16 HMR uses a WebSocket on `/_next/hmr`.** Verified through the
  gateway over IPv4 and IPv6; no special-casing was needed because the gateway
  pipes upgrades generically.
- **Oj adapter is slower than stdlib as written** (it normalises in Ruby
  first). The stdlib default stands; the adapter will be reworked and
  re-measured in Phase 3 (docs/performance.md).
- **Readiness probes open empty connections.** The supervisor probes upstream
  ports by connecting; Puma and Next.js tolerate this.
- **Overlapping file watchers must be re-baselined together** after a restart,
  or one change restarts the API twice.

## D-018 Sequel for the database layer (confirms P-101)

**Decision.** `gemstack-db` builds on Sequel 5 with the `pg` driver.
`GemStack::Model` is an anonymous subclass of `Sequel::Model` with GemStack
conventions (timestamps, validation helpers, `field`, `validates`,
`input_schema`, `find` raising 404). The full Sequel API stays available.

**Reasoning.** Mature and actively maintained, fast, first-class PostgreSQL
support, a thread-safe pool, migrations and plugins — without ActiveSupport's
global patches. Confirmed with the user before implementation.

**Consequences.** `Model.find(id)` raises `RecordNotFound` (404) for a scalar id
and keeps Sequel's semantics for a hash or block (a small, documented
deviation). Non-numeric ids for integer keys are a 404, never an SQL error.
`GemStack::Model` must stay anonymous (`Class.new(Sequel::Model)`): a named
subclass makes Sequel look for a "models" table at require time. A regression
test guards this, because RuboCop's autocorrect rewrote it once.

## D-019 Module graph for Phase 2

```text
core ← schema ← http ← contract
core ← schema ← db            (db never depends on http)
umbrella → core, schema, http, contract, dev, cli     (not db)
```

**Decision.** Three new gems: `gemstack-schema` (types, request schemas,
serializers — pure Ruby), `gemstack-db` (optional: Sequel + pg), and
`gemstack-contract` (TypeScript/OpenAPI generation). The umbrella doesn't
depend on `gemstack-db`, so API-only apps need no native `pg` extension.

**Reasoning.** Types are shared by models, request schemas, serializers and
generators, so they live below all of them. Serialization and validation are
independent of HTTP and of the database. The architecture test enforces the
order of the graph.

## D-020 Error translation registry in core

**Decision.** `GemStack::ErrorMapping.register(ExceptionClass) { |e| GemStack::Error }`.
The HTTP error renderer translates exceptions through it before rendering.

**Reasoning.** `gemstack-db` must map Sequel errors (not found → 404,
validation → 422 with field errors, unique/not-null/FK violations → 422 with
the column PostgreSQL reports, still-referenced rows → 409, connection
problems → 503) without depending on the HTTP gem. Applications can register
their own mappings for third-party errors the same way.

## D-021 Request input: `accepts` + `input`, flat JSON bodies

**Decision.** Controllers declare request schemas at class level
(`accepts :create, with: Product.input_schema`, `partial: true` for updates,
or a block), and read validated data with `input`. `params.validate { ... }`
exists for ad-hoc validation. Generated code sends flat JSON bodies
(`{"name": ...}`), not Rails-style wrapped ones.

**Reasoning.** Class-level declarations are introspectable, so the same schema
validates requests *and* types the generated TypeScript client (DRY). Schemas
are allow-lists and coerce types, which replaces strong-parameter
bookkeeping. `Product.input_schema` derives the schema from the model's
`field` declarations, so a field is declared once. Flat bodies keep the
TypeScript client and forms simple.

## D-022 Decimals travel as strings (confirms P-102)

`decimal` → JSON string → TypeScript `string`; inputs accept numbers or
strings. Values are exact but not padded to the column's scale ("39.9", not
"39.90") — formatting belongs in the UI.

## D-023 Contract conventions

**Decision.** Response types follow conventions:
`index → [<Resource>Serializer]`, `show/create/update → <Resource>Serializer`,
`destroy → no body`. Anything else is `unknown` with a warning, until declared
with `returns :action, Type`. Request types come from `accepts` (a body for
non-GET, a query for GET). Generated shapes are TypeScript `type` aliases, so
they're assignable to the client's query record type. Generated files carry a
header, are rewritten only when their content changes (no needless Next.js
reloads), and stale ones are removed. `gemstack dev` regenerates them in the
background when `app/` or routes change.

**Reasoning.** Conventions cover generated CRUD with zero declarations; one
line covers custom endpoints. Deriving types from serializers — not columns —
means hidden columns never appear in frontend types.

## D-024 Models may load before their table exists

`GemStack::Model.require_valid_table = false`, so the contract can be
generated right after `generate resource`, before `db:migrate`. Queries
against a missing table still fail with a clear "relation does not exist".
Sequel's own existence probes are kept out of the error log (`QueryLogger`).

## D-025 Generators: fields are required unless `:optional`

`name:string` becomes `NOT NULL` with a presence validation; `:optional` makes it
nullable. Booleans are `NOT NULL DEFAULT false`. `references` adds a foreign key
(`ON DELETE RESTRICT`), an index and `belongs_to`. Safer data by default, and
the edit to relax it is obvious.

## D-026 Generated tests use sample data derived from fields

`GemStack::DB::Testing.sample_attributes(Model)` / `sample_payload(Model)`
build valid values from `field` declarations at runtime (types, size, bounds,
`in:`, sequences for uniqueness, referenced records for `references`).
Generated tests therefore keep passing when fields change. Tests run inside
rolled-back transactions; `prepare!` creates and migrates the test database.

## D-027 `.env` is loaded before configuration is read

`config/app.rb` starts with `GemStack.setup(root: ...)`, which sets the root and
loads `.env` files immediately. Found during end-to-end testing: loading them
at boot was too late for commands that read configuration before booting
(`db:create`, the test helper's `prepare!`).

## D-028 The test database has its own variable

The test environment reads `TEST_DATABASE_URL` (default `postgres:///<app>_test`),
never `DATABASE_URL`, so a development URL in `.env` can't be wiped or mutated
by the test suite.

## D-029 Findings recorded during Phase 2 verification

- **json 3.0 removed `create_additions:`** from `JSON.parse`. Generated apps
  resolved json 3 while the monorepo was locked to 2.18, so the monorepo now
  tests against json 3. (`JSON.parse` never creates additions by default.)
- **`DB.disconnect` must keep the Database object.** Replacing it left models
  holding a stale reference, so writes and test transactions ran on different
  pools. `disconnect` now only closes pooled connections (safe for Puma's
  `before_fork`).
- **Ruby 3 keyword-argument pitfall:** `Schema.call(input, path: nil)` turned
  `call("q" => "x")` into keywords. Public APIs that take a data hash take it
  positionally only.
- **CLI commands log at WARN** and hide SQL; the dev server logs SQL at DEBUG.

## D-030 Ruby 4.0 is the minimum version

**Decision.** All GemStack gems declare `required_ruby_version >= 4.0`. The
framework is developed and tested on Ruby 4.0.7, the latest release when this
was decided. Generated apps pin their Ruby in `.ruby-version` and
`.tool-versions`.

**Reasoning.** GemStack is a new framework with no installed base to keep
compatible, so it can target the current Ruby. That brings the latest YJIT and
performance work, and avoids carrying compatibility code. Requested by the user.

**Consequences.** Ruby 4 moved some libraries from default gems to bundled
gems, and bundled gems must be listed in a Gemfile to load under Bundler.
Generated apps list `irb` (for `gemstack console`); the monorepo lists
`benchmark` (for `rake bench`).

## D-031 Distribution: real gems, installed like Rails

**Decision.** GemStack ships as eight normal gems. `rake gems:install` builds
them into `pkg/` and runs `gem install` in dependency order, which puts the
`gemstack` executable on the PATH exactly like `gem install rails` would. When
the CLI runs from an installed gem, new apps depend on `gem "gemstack", "~> x.y.z"`.
When it runs from a checkout (`bin/gemstack`), they use a `path` block instead.

**Security note.** The names `gemstack` and `gemstack-*` were unregistered on
RubyGems.org when checked (2026-09-28). An app whose Gemfile says
`gem "gemstack"` could resolve a *different*, higher-versioned gem if someone
registered the name first (dependency confusion). Before sharing GemStack
apps, claim the names on RubyGems.org, or serve the gems from a private gem
server.

## D-032 Findings recorded while moving to Ruby 4 and installed gems

- **Bundler 4 rewrites `Gemfile.lock` on every `bundle exec`** (identical
  content, new mtime). Because Puma's start touched a watched file, `gemstack dev`
  looped restarting the API. The file watcher now confirms mtime changes with a
  content digest (SHA-256, only computed when the mtime changes).
- RuboCop's Ruby 4 target suggested anonymous `&` forwarding into a nested
  block; this is valid on Ruby 4 and was verified by running the benchmark.
- `require "pathname"` is redundant on Ruby 4 (Pathname is core).

## D-033 Compression middleware (confirms P-105)

**Decision.** `Middleware::Compression`, placed after the request logger and
before the error handler, so error responses are compressed too. It
negotiates `Accept-Encoding` with q-values and prefers Brotli when the
optional `brotli` gem is installed, else gzip. It compresses JSON, text, JS,
XML and SVG bodies of at least 1 KB whose size is known. It never touches
HEAD, 1xx/204/304 responses, already-encoded responses, `no-transform`,
Server-Sent Events or streamed bodies. It always sends
`Vary: Accept-Encoding` for compressible types and weakens strong ETags.

**Why our own.** `Rack::Deflater` only does gzip and has no size threshold.
The middleware is ~120 lines and fully tested.

**Levels, from measurements** (docs/performance.md). On a varied 26 KB JSON
body, gzip 6 costs 481 µs for 27.2%, gzip 4 costs 246 µs for 29.1%, and
Brotli 4 costs 210 µs for 28.9%. **Defaults: gzip 4, Brotli 4** — half the
CPU of gzip 6 for about 2 points of size. Brotli 11 took ~15 ms per response
and is unsuitable for dynamic content.

**Security.** BREACH-style attacks need a secret *and* attacker-controlled
input reflected in the same compressed response. Apps returning such bodies
should disable compression for those responses
(`headers["cache-control"] = "no-transform"`) or globally
(`config.http.compression.enabled = false`). Documented in docs/performance.md.

## D-034 Pagination envelope: `{ data, meta }`, typed as `Paginated<T>`

**Decision.** `paginate(dataset)` reads `page` / `per_page` (validated: 422 on
invalid values; `per_page` clamped to `max_per_page`, default 100) and returns
a `Page` that renders as `{"data": [...], "meta": {"page", "per_page", "total", "total_pages"}}`.
`returns :index, GemStack::Page[ProductSerializer]` makes the contract emit
`list(query?: PaginationQuery): Promise<Paginated<Product>>`. Generated `index` actions
paginate by default, and generated pages keep `?page=` in the URL.

**Reasoning.** Unbounded `index` responses are a production hazard. An
envelope is explicit and typed, whereas pagination in headers is invisible to
the typed client. Offset pagination suits the conventional admin/list case;
keyset (cursor) pagination for very large tables can be added later behind
the same `Page` shape.

## D-035 Caching: `gemstack-cache` with memory, null and Redis stores

**Decision.** A small gem (depends on core only, included by the umbrella)
providing `GemStack.cache` with `fetch/read/write/delete/exist?/increment/decrement/clear`.
Stores:
- `:memory` (default): a per-process LRU with TTL. Values are marshalled, so
  cached objects are never shared or mutated.
- `:null` (default in test).
- `:redis` via `redis-client` (optional gem): a pooled connection, atomic
  `INCRBY`, and a `clear` limited to the app's namespace (never `FLUSHDB`).
- Any object implementing the interface.

**Reasoning.** "Don't force Redis": a single-process app gets a working cache
with no infrastructure, and multi-process deployments switch one setting.
`redis-client` is the maintained low-level client used by Sidekiq 7 and
redis-rb 5. Stampede protection (`race_condition_ttl`) is deliberately left
for later.

## D-036 ETags and 304s from Rack's middleware

**Decision.** `Middleware::ETags` wraps `Rack::ConditionalGet` + `Rack::ETag`
(reuse, not reinvention), and `config.http.etags` turns both off. Controllers
get `stale?(etag:, last_modified:)` / `fresh_when`, which skip rendering
entirely for fresh requests, plus `cache_control`. GemStack models provide
`cache_key` (`"product/42-<updated_at>"`) for record ETags.

**Cost.** About 2 µs per request (measured); the benefit is bandwidth and
client-side revalidation.

## D-037 JSON: stdlib stays the default (confirms D-006 with evidence)

The Oj adapter was reworked to try Oj's C strict mode first (it accepts
symbol keys) and fall back to normalisation only for non-native values. On
serializer output, stdlib `JSON::Coder` (json 3.0) is still faster: 4.3 µs vs
7.0 µs for 20 records, and 19.8 vs 34.2 µs for 100, with 1 allocation vs 42–202.
Oj remains available as `config.http.json = :oj`.

## D-038 Serializers compile an execution plan

**Finding.** Serialization dominated JSON response time: 90 µs for 20
records, versus ~14 µs for the whole middleware + routing + controller path.
**Change.** Each serializer class compiles `[name, block, dumper]` once (types
resolved to lambdas, no per-value lookups), and decimals no longer
round-trip through strings. **Result.** 20 records: 90 → 30 µs (interpreter),
52 → 18 µs (YJIT), with half the allocations.

## D-039 YJIT on by default in production

**Decision.** `config.jit` defaults to `:yjit` in production (`nil` elsewhere,
`:zjit` opt-in, `GEMSTACK_JIT=yjit|zjit|off`). It is enabled at boot unless a
JIT is already running.

**Evidence** (Puma, 5 threads, `ab -k -c 10`, median of 5 runs, 20-record
endpoint): interpreter 17.6k req/s, **YJIT 22.3k (+27%)**, ZJIT 18.8k (+7%). In
micro-benchmarks YJIT made the serializer 42% faster and a request 26% faster.
ZJIT is newer; revisit when it matures.

## D-040 Background jobs: a built-in PostgreSQL queue by default (confirms P-103)

**Options presented to the user:** a built-in PostgreSQL queue (recommended),
Sidekiq as the default, or Que. Solid Queue and GoodJob were excluded because
they require ActiveRecord and Railties (conflicts with D-018). **The user chose
the built-in PostgreSQL queue.**

**Design** (`gemstack-jobs`, which depends on core only; the `:postgres`
adapter loads gemstack-db on demand):
- **Enqueue:** a row in `gemstack_jobs`, inserted on the current connection.
  Enqueueing inside a transaction is atomic with the data, and `NOTIFY`
  (itself transactional) wakes idle workers.
- **Workers:** each claims one job with
  `UPDATE … WHERE id = (SELECT … FOR UPDATE SKIP LOCKED LIMIT 1) RETURNING`.
  Performing happens outside any transaction. Success deletes the row;
  retries reschedule it with backoff; exhausted jobs keep `failed_at`.
- **Crash safety:** a reaper releases locks older than `lock_timeout`, giving
  at-least-once delivery. Graceful shutdown releases unfinished jobs.
- **Consistency:** one `Executor` decides performed / retry / discard / fail
  for every adapter (postgres, async, inline, test, sidekiq).
- **Safety:** arguments are validated as JSON at enqueue time. Only
  `GemStack::Job` subclasses are ever instantiated from a queue row.
- **New apps stay empty:** the table's migration is added by the first
  `generate job` (or `jobs:install`), not by `gemstack new`.

**Measured:** in `gemstack dev`, a job was picked up 3 ms after the HTTP
request that enqueued it committed (NOTIFY, not polling).

## D-041 Compatibility patch: Sequel JSON parsing on json 3

Sequel ≤ 5.108 calls `JSON.parse(json, create_additions: false)`; json 3.0
removed that option, so every `jsonb` read raised `ArgumentError`. Found
by the job queue tests, which read `jsonb` arguments. gemstack-db prepends
`Sequel.parse_json` (a public Sequel hook) to call `JSON.parse(json)`, which
never creates additions, so behaviour is unchanged. It applies only when
json ≥ 3.0 is loaded, and a model test now reads JSONB. Remove it once Sequel
ships a fix.

## D-042 Log output is unbuffered

Ruby buffers `$stdout` when it is a pipe, so under `gemstack dev` (or any
process manager) a worker's log lines appeared only when it exited.
`GemStack::Logger` now sets `sync = true` on its output. Generated
migrations also get unique timestamps: two migrations generated in the same
second no longer share a version.

## D-043 Names: explicit namespaces, clash checks, and an end-to-end check

Generated-app testing found name collisions that unit tests couldn't. The fixes:
- **`GemStack::Page`, not `Page`.** Phase 3 aliased `Page` inside
  controllers, which would shadow an app's own `Page` model. Pagination is now
  always written `returns :index, GemStack::Page[ProductSerializer]`.
- **TypeScript helpers are `Paginated<T>`, `PaginationMeta` and
  `PaginationQuery`,** so a resource named `Page` produces valid TypeScript. The
  contract refuses user types that take one of these reserved names, instead of
  emitting duplicate identifiers.
- **Generators refuse class names that clash** with Ruby core/stdlib or
  loaded gems (a job named `Digest` would reopen Ruby's `Digest` module), and
  suggest an alternative (`DigestJob`). GemStack's own names (`Job`, `Page`,
  `Model`, …) are namespaced and stay usable as app names.
- **Generated forms** cast their change handler's value to the field's type
  (a single-field form failed `tsc`).
- **`script/e2e`** generates an app with every field type and the known edge
  cases (single field, `Page`, a reference, read-only, API-only, a job, a
  reserved name), then runs its Ruby tests, `tsc` and `next build`. Run it
  before releases.

## D-044 Realtime: SSE over hijacked sockets, PostgreSQL fan-out (confirms P-104)

**Decision.** `gemstack-realtime` (optional; added with `gemstack add realtime`):
- **API:** `GemStack.broadcast(channel, event, data)` serializes data like
  `render` (the shared `Serializer.render`).
- **Endpoint and connections:** `GET <api_path>/realtime?channels=…` serves
  Server-Sent Events. The socket is taken over from Puma (Rack full hijack)
  and handed to one nio4r event loop per process, which handles writes,
  disconnect detection and heartbeats.
- **Fan-out:** a pluggable broker, PostgreSQL LISTEN/NOTIFY by default
  (Redis, memory and test brokers also available).
- **Replay:** a per-process replay buffer (Last-Event-ID), and `gemstack.gap`
  when replay is impossible.
- **Channel rules:** deny-by-default channels in `config/channels.rb`, with
  pattern captures passed to authorization blocks.
- **Client:** `realtime.ts` multiplexes one EventSource per tab and provides
  `useRealtime`.

**Why SSE and no WebSocket transport in this phase.** Notifications, live
updates, dashboards and chat-receive are one-way server → client flows, and
client → server messages are ordinary API requests (with validation,
authorization and the contract). SSE is plain HTTP: it passed through the dev
gateway, Next.js rewrites (verified in production mode) and proxies without
special handling, and browsers reconnect with Last-Event-ID on their own. A
WebSocket transport would add a dependency (`websocket-driver`) and a second
code path for little gain. The broker/hub/connection split leaves room for one
later.

**Why hijack + nio4r.** Holding a Puma thread per open stream would cap
realtime users at the thread count. nio4r is already installed with Puma.
Measured: 20 open streams on a 2-thread server, and ordinary requests are still
answered.

**Measured end to end** (`gemstack dev`, examples/shop): POST → transaction
(product + job) → worker → `GemStack.broadcast` → NOTIFY → API process → SSE
through the gateway, in **41 ms**.

**Limits.** PostgreSQL NOTIFY payloads are ≤ 8 KB (a clear error points to
smaller payloads or the Redis broker). Replay is per process and bounded.
There is no presence yet.

## D-045 One refused channel doesn't fail the stream

Because a tab multiplexes all its channels on one stream, a 403 for one
channel would silently drop all the others. The endpoint serves the
authorized channels and sends `gemstack.denied` to the refused channel's
handlers; it returns 403 only when nothing is allowed. Found while running the
real TypeScript client against a live server.

## D-046 Findings recorded during Phase 5

- **Recursive lock:** `Realtime.listen!` held the module mutex while lazily
  building the broker, which takes the same mutex, so the first real
  connection deadlocked. Tests had preset the broker; a regression test now
  covers the lazy path.
- **Identity sets:** the hub uses identity-based sets, so a subscriber whose
  state changes can still be removed.
- **`Regexp.last_match`:** `gemstack add` read `Regexp.last_match` after
  another regex inside the same block had overwritten it, so the `path` line
  was lost. Capture groups are now read before running other regexes.
- **SSE through Next.js rewrites** was claimed in D-010 but unverified; it is
  now verified in production mode.

## D-047 Mail: the `mail` gem, ERB templates, delivery through jobs

**Decision.** `gemstack-mail` wraps the `mail` gem (message building, MIME,
SMTP) rather than reimplementing any of it. Mailers are classes whose public
methods are actions; `Mailer.action(args)` returns a `Delivery` with
`deliver_now` / `deliver_later`. Templates are ERB (Erubi) next to the mailer
in `app/mailers/templates/`; HTML templates escape by default. Delivery
methods: `:smtp` (configured by one `SMTP_URL`), `:log` (development: saved
to `tmp/mail` as `.eml` and `.html`), `:test`, or any object with
`#deliver(message)` for API providers.

**Reasoning.** `deliver_later` goes through `GemStack::Jobs`, so failed
deliveries retry with backoff and, with the PostgreSQL queue, an email enqueued
in a rolled-back transaction is never sent. Arguments must be JSON values
(ids, not records) — the job rule from D-040. An action that returns without
calling `mail` sends nothing, so a job for a since-deleted user doesn't fail
and retry forever. `DeliveryJob` is autoloaded so a worker process can
resolve the class name it finds in the queue.

## D-048 Sessions: random tokens in HttpOnly cookies, rows in the database

**Context.** The user chose "cookies + API tokens". Options for the browser
side: signed/encrypted cookie sessions, JWTs, or server-side sessions.

**Decision.** A 256-bit random token in an HttpOnly, `SameSite=Lax` cookie
(`Secure` and `__Host-session` in production); the `sessions` table stores its
SHA-256 digest with user, IP, user agent, `last_seen_at` and a sliding 30-day
expiry (extended at most every 5 minutes, so reads don't write).

**Reasoning.** Server-side rows can be listed and revoked — a password reset
or "sign out everywhere" really ends sessions, which signed cookies and JWTs
can't do without a denylist. Digest-only storage means a database leak doesn't
yield working sessions. Because Next.js and the API share an origin (D-010),
the cookie works with no CORS or token handling in JavaScript, where XSS could
read it. Sign-in always issues a new token (no session fixation). The lookup is
one indexed query per authenticated request.

## D-049 Passwords: Argon2id through the `argon2` gem

**Decision.** Argon2id, t=2, m=32 MiB, p=1 (≈35 ms per hash, measured),
configurable; cheap parameters in tests. bcrypt hashes from other systems still
verify when the app adds the `bcrypt` gem, and every hash weaker than the
current settings is upgraded on the next successful login. Length 12–128
characters, no composition rules; plaintext longer than 1 KB is never hashed.

**Reasoning.** Argon2id is OWASP's first recommendation and memory-hard; the
`argon2` gem binds the reference C implementation — GemStack implements no
cryptography. Parameters above OWASP's minimum (19 MiB, t=2) while keeping login
latency small. NIST SP 800-63B favours length over composition rules.

## D-050 Account flows that don't leak account existence

Login gives one answer for "unknown email" and "wrong password" and spends
the same time on both (a dummy Argon2 verification). Forgot-password always
answers 202. Reset and verification tokens are single use (consumed with an
atomic `DELETE … RETURNING`), expire (1 h / 3 d), are stored as digests, and a
new one invalidates older ones; a verification token is bound to the address it
was sent to. A password reset ends every session. Signup does reveal that an
address is taken — a deliberate usability trade-off, rate limited.

## D-051 CSRF: refuse cross-site writes using Fetch Metadata

**Decision.** No CSRF tokens. `GemStack::Auth::Controller` refuses unsafe
requests (POST/PUT/PATCH/DELETE) whose `Sec-Fetch-Site` isn't `same-origin`
(or `none`), falling back to comparing `Origin` with the host for older
browsers; `config.auth.trusted_origins` allows named origins. Requests with
neither header aren't from browsers and can't carry a victim's cookie; requests
authenticated only by a bearer token can't be forged cross-site.

**Reasoning.** Together with `SameSite=Lax` this is the defence OWASP now
recommends for same-origin apps, and it needs nothing from the frontend — no
token endpoint, no hidden fields, nothing to forget in a hand-written `fetch`.

## D-052 Policies: plain classes, deny by default

`GemStack::Policy` (in `gemstack-auth`): one class per model, predicate
methods (`show?`…) that default to `false`, and a `Scope#resolve` that raises
until defined. Controllers get `authorize!` (403), `policy_scope` and `policy`.
Pundit-shaped on purpose — familiar, tiny, and replaceable by Pundit or Action
Policy.

## D-053 Storage: direct uploads with signed URLs

**Decision.** Browsers upload straight to storage: the API validates type and
size and returns a presigned `PUT` (S3: content type and exact length are in
the signature; disk: a signed token checked by `Storage::Endpoint`). The server
chooses keys (`uploads/YYYY/MM/<uuid>/<name>.<ext>`, extension derived from
the validated type), and records reference files by a signed id, so clients
can't attach other people's files. No attachment models or image processing
yet.

**Reasoning.** Keeps large bodies away from Ruby processes and
`max_body_size` small. One browser flow works for disk (development) and S3,
R2 or MinIO (production). SVG and HTML are refused by default and
disk-served files carry `nosniff` and `CSP: sandbox`, because uploaded
content is untrusted.

## D-054 Secrets and findings recorded during Phase 6

- **`SECRET_KEY_BASE`** (core): required in production; generated per
  environment in `tmp/` for development and tests. `GemStack.key_for(purpose)`
  derives independent keys (HMAC), so storage signatures and future uses never
  share a key.
- **Rate limits** live in `gemstack-auth` (`rate_limit to:, within:, by:`) and
  count in `GemStack.cache`; with the default null store in tests they never
  fire, so app tests aren't order-dependent.
- **Missing tables:** `gemstack contract` right after `gemstack add auth` ran
  Sequel's schema queries against tables that weren't migrated yet and logged
  two errors per model. `GemStack::Model` now checks `to_regclass` first.
- **`base64`** isn't a default gem in Ruby 4; the storage signer uses
  `pack("m0")`. Only the generated app caught this — the monorepo bundle
  pulls base64 in through another gem.
- **Workers and lazily-required jobs:** the live dev check showed the worker
  couldn't resolve `GemStack::Mail::DeliveryJob` (D-047's autoload).

## D-055 Development error pages for browsers only

When `show_exceptions` is on and a request is a top-level browser navigation
(`Sec-Fetch-Dest: document`, or `Accept: text/html` for older browsers), a
500 renders an HTML page: message, source excerpt of the first app frame,
backtrace with app frames highlighted and gem paths shortened. Everything
else — `fetch`, the generated client, curl — keeps the JSON envelope, whose
`exception` field the TypeScript client now prints to the console in
development. Self-contained HTML with a strict CSP, no JavaScript; 4xx errors
stay JSON (they are answers, not bugs). Production is unchanged.

## D-056 API docs: built-in, live, development only

`/api/docs` is a single self-contained page (no CDN: works offline, sends
nothing anywhere, strict CSP) that renders an OpenAPI document built from the
live routes on each request, with TypeScript-style types matching the
generated client and a "try it" form that uses the session cookie. Swagger UI
or Scalar would add a large dependency or a CDN request for a development
convenience. Off in production by default: an endpoint map is reconnaissance
material. `openapi.json` remains for external tools.

## D-057 `gemstack doctor`

Independent checks (a failure never hides the others), each with the fix as a
command. Exit status 1 on problems, so it works in CI and in a container
before a release. `--production` checks the environment a deploy needs. It
also fails when `.env`, key files or generated secrets are tracked by git and
says to rotate them — removing a file doesn't remove it from history.

## D-058 Deployment recipes: generated files, not a deploy tool

`gemstack generate deploy` writes a multi-target Dockerfile (`api`, `web`),
`compose.yaml` (Postgres, a one-shot migration, API, jobs, Next.js, Caddy),
a `Caddyfile`, a `Procfile` and `.dockerignore`. GemStack doesn't deploy
anything: platforms change faster than frameworks, and the files are
readable enough to adapt. Images are non-root, secret-free (runtime
environment only; `.env*` excluded from the build context) and health-checked.
Verified by building the images and running the stack in production mode:
`__Host-` Secure cookie over HTTPS, HSTS, docs 404, jobs worker running.

## D-059 No published npm package (yet)

The client runtime stays a vendored, app-owned file (`frontend/lib/gemstack/`,
D-026): apps customise it (auth headers, logging) and it has no version skew
with the backend that generated the types. Publishing a package to the public
npm registry is also a public release, which needs a deliberate review of
what goes out; it isn't needed for anything GemStack does today. Revisit if
several frontends share one backend.

## D-060 Findings recorded during Phase 7

- **Production eager loading**, not caught by any test until the Docker run:
  the image failed with `uninitialized constant GemStack::Page` because
  `rake gems:install` reinstalling the same version left RubyGems' cached
  `.gem` stale, and `bundle cache` copied that. The task now refreshes the
  cache; the e2e also reminded that apps from a checkout can't be built into
  images without `bundle cache --all` (the generator warns).
- **Docs page rendering**: nested child arrays weren't flattened, which only a
  real browser (headless Chrome screenshot) showed.

## D-061 Publishing: one repository, fourteen gems, one version

**Decision.** Everything lives in `gemstack-rb/gemstack`. Each directory in
`gems/` is published from it to rubygems.org as a separate gem by
`script/release`, in dependency order. All gems share one version, set with
`rake version:set[x.y.z]`, and depend on each other with exact pins, so there
is no compatibility matrix. The `gemstack` gem depends on the modules every
app needs; database, jobs, realtime, mail, storage and auth stay opt-in
(D-003's layering unchanged).

**Reasoning.** rubygems.org doesn't care where code lives, so separate gems
don't need separate repositories. Features routinely touch several gems
(Phase 6 changed core, db, mail, contract and cli together); in one repository
that is one change, tested together by `rake`, the architecture test and
`script/e2e`, and released by one script. Per-gem repositories — developed
separately or as read-only mirrors — were considered and dropped: they add a
coordination or sync step to every release and give users nothing the gem
pages and the monorepo don't (Rails does the same).

**Consequences.** Every gem's metadata points to the monorepo (source,
changelog, issues, docs). Gemspecs carry their version inline, so any gem
directory builds on its own; the architecture test checks one version, exact
internal pins, MIT license, MFA-required pushes and the links.
`script/release` skips versions already on rubygems.org, so an interrupted
release is finished by running it again. Per-gem mirrors can be added later
(`git subtree split`) without changing any of this.

## D-062 SQLite, PostgreSQL and MySQL; config/database.yml

**Context.** GemStack started PostgreSQL-only (D-018). Users asked for a
Rails-style `config/database.yml` and for MySQL and SQLite.

**Decision.** `gemstack-db` supports SQLite (`sqlite3`), PostgreSQL (`pg`)
and MySQL 8 (`mysql2` or `trilogy`), all through Sequel; the driver is the
app's gem, not a dependency of `gemstack-db`. Settings come from, first match
first: `config.db.url`, `DATABASE_URL` (`TEST_DATABASE_URL` in tests),
`config/database.yml` (Rails' format and key names, ERB), then PostgreSQL
`<app>_<env>` for apps without the file. `gemstack new` takes
`--database=sqlite3|postgresql|mysql2|trilogy` and defaults to **SQLite**
(the user's choice): a new app runs with nothing to install.

Migrations stay portable: PostgreSQL type names used by the generators
(`timestamptz`, `jsonb`, `uuid`, `inet`) map to the closest native type on
MySQL and SQLite, so one migration runs everywhere. Times are stored in UTC on
every adapter (`Sequel.database_timezone = :utc`). SQLite runs in WAL mode
with a 5 s busy timeout, so Puma threads and a jobs worker can share the file.
JSON fields are (de)serialized outside PostgreSQL. Constraint errors map to
field errors from each database's messages; SQLite doesn't say which side of
a foreign key failed, so those are 409s.

**Reasoning.** Sequel already speaks all three; the work was in the places
GemStack had used PostgreSQL features directly. `database.yml` is what Rails
developers expect, and `DATABASE_URL` winning keeps hosting platforms working
unchanged. Every database-backed suite (db, jobs, auth) runs on all four
drivers (`rake test:databases`), and `script/e2e` builds and tests a full app
on each.

## D-063 The job queue on every database

The `:database` adapter (`:postgres` remains an alias) claims one job at a
time in a short transaction: `FOR UPDATE SKIP LOCKED` on PostgreSQL and MySQL
8; on SQLite an immediate transaction takes the write lock, which serializes
claimers. Times come from Ruby in UTC, so neither the database clock nor its
time zone matters. PostgreSQL keeps `NOTIFY` wake-ups (5 s safety poll);
MySQL and SQLite poll every second. One migration creates the table on all
three (partial indexes where supported). Realtime keeps `LISTEN/NOTIFY` on
PostgreSQL; elsewhere cross-process fan-out uses the Redis broker (chosen
automatically when `REDIS_URL` is set), and `gemstack doctor` warns when a
jobs worker would broadcast through the in-process memory broker.

## D-064 Findings recorded while adding MySQL and SQLite

- MySQL can't index `TEXT` without a length: the auth tables' unique columns
  are now `String` (varchar), which also suits PostgreSQL.
- MySQL reports an omitted `NOT NULL` column as "Field 'x' doesn't have a
  default value" (not a constraint error); it now maps to a 422 field error.
- Sequel's table-existence probes are quoted differently per adapter (`"`, `` ` ``,
  `'`); probes are filtered from error logs, and GemStack checks tables through
  the catalog (`to_regclass`, `information_schema`, `sqlite_master`) instead.
- A jobs test assumed NOTIFY and timed out on MySQL; tests now use the
  mechanism each adapter actually has.

---

## Proposed decisions (future phases)

### P-101 Sequel as the database foundation — **Accepted as D-018**

ActiveRecord is the most popular ORM but pulls in ActiveSupport and its
global monkey patches; ROM is powerful but heavy conceptually. **Sequel** is
mature (15+ years), actively maintained, fast, has first-class PostgreSQL
support (prepared statements, `RETURNING`, `LISTEN/NOTIFY`, JSONB), a thread-safe
connection pool, migrations, and a plugin system. GemStack's `Model`
(`field`, `validates`) will be a thin layer over `Sequel::Model`, with the
full Sequel API available underneath.

### P-102 Decimal serialised as string — **Accepted as D-022**

JSON numbers are IEEE doubles in JS; money must not lose precision. Default:
`decimal` → JSON string → TS `string`. Configurable per field/app.

### P-103 Default job backend on PostgreSQL — **Accepted as D-040**

Most GemStack apps already run PostgreSQL; requiring Redis only for jobs adds
infrastructure. Evaluate Que / GoodJob-style `SKIP LOCKED` designs; provide a
Sidekiq adapter for Redis users. The adapter interface keeps the choice
reversible.

### P-104 SSE by default for realtime — **Accepted as D-044** (WebSocket transport deferred)

See ARCHITECTURE §10. Fan-out through Postgres `LISTEN/NOTIFY` by default.

### P-105 Compression — **Accepted as D-033**

Own small middleware (Rack::Deflater lacks Brotli and size thresholds):
negotiate `br` (if the `brotli` gem is available) then `gzip`, skip bodies
under 1 KB, already-encoded responses, `text/event-stream`, images/archives,
`HEAD`/204/304; always set `Vary: Accept-Encoding`. BREACH considerations
documented.
