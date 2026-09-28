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

## D-034 Pagination envelope: `{ data, meta }`, typed as `Page<T>`

**Decision.** `paginate(dataset)` reads `page` / `per_page` (validated: 422 on
invalid values; `per_page` clamped to `max_per_page`, default 100) and returns
a `Page` that renders as `{"data": [...], "meta": {"page", "per_page", "total", "total_pages"}}`.
`returns :index, Page[ProductSerializer]` makes the contract emit
`list(query?: PageQuery): Promise<Page<Product>>`. Generated `index` actions
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

### P-103 Default job backend on PostgreSQL (Phase 4) — Proposed

Most GemStack apps already run PostgreSQL; requiring Redis only for jobs adds
infrastructure. Evaluate Que / GoodJob-style `SKIP LOCKED` designs; provide a
Sidekiq adapter for Redis users. The adapter interface keeps the choice
reversible.

### P-104 SSE by default for realtime, WebSocket as adapter (Phase 5) — Proposed

See ARCHITECTURE §10. Fan-out through Postgres `LISTEN/NOTIFY` by default.

### P-105 Compression — **Accepted as D-033**

Own small middleware (Rack::Deflater lacks Brotli and size thresholds):
negotiate `br` (if the `brotli` gem is available) then `gzip`, skip bodies
under 1 KB, already-encoded responses, `text/event-stream`, images/archives,
`HEAD`/204/304; always set `Vary: Accept-Encoding`. BREACH considerations
documented.
