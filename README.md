# GemStack

**A fast, modular Ruby API framework for Next.js applications.**

GemStack lets you start a Ruby + Next.js + TypeScript application and go straight
to business logic. One command gives you a Ruby API and a Next.js frontend served
from **one origin**, with production-ready defaults (security headers, request
IDs, structured logs, body limits, JSON errors) and no plumbing to wire.

```bash
gemstack new shop
cd shop
gemstack dev          # → http://localhost:3000
```

```text
                 Browser
                    │
             localhost:3000          one origin: no CORS, no API URL, no proxy config
                    │
             GemStack gateway
               /          \
         Next.js           /api/*  → Ruby (Rack + Puma)
```

> **Status: Phases 1–7 complete — see [ROADMAP.md](ROADMAP.md).**
> Built: HTTP layer, router, middleware, controllers, single-origin dev server,
> Next.js + TypeScript template, PostgreSQL models (Sequel), migrations,
> validation, serializers, TypeScript/OpenAPI contract, `generate resource`.
> Phase 3: compression, ETags/304, pagination, `GemStack.cache`, YJIT by default, benchmarks.
> Phase 4: background jobs on PostgreSQL (transactional, SKIP LOCKED, NOTIFY), Sidekiq adapter.
> Phase 5: realtime — `GemStack.broadcast` → Server-Sent Events, PostgreSQL fan-out, `useRealtime`.
> Phase 6: `gemstack add auth` (Argon2id, cookie sessions + API tokens, reset/verification emails,
> Next.js pages), policies, mail, `gemstack add storage` (direct uploads to disk/S3).
> Phase 7: dev error pages, `/api/docs`, `gemstack doctor`, `gemstack generate deploy` (Docker, Caddy, Procfile).

## Why

- **Convention over configuration.** Routes live under `/api`, code in `app/`
  autoloads, the dev server picks its own internal ports. Configure only what
  differs.
- **Smart defaults, not rigid defaults.** Every subsystem can be configured,
  swapped (codec, middleware, adapters) or replaced — it's plain Rack, plain
  Bundler and plain Next.js underneath.
- **Not Rails.** API-first, small core, no server-rendered views, no default
  User/auth/CRUD. The generated app is intentionally empty.
- **Normal ecosystems.** Any gem via the Gemfile, any npm package in
  `frontend/`.
- **Fast by default, measured.** O(1) static routing, a compiled middleware
  stack, lazy body parsing, C-backed JSON — with benchmarks in `benchmarks/`.

## A taste

```bash
gemstack generate resource Product name:string price:decimal description:text:optional
gemstack db:migrate
```

generates the migration, model, serializer, controller, routes, tests, a typed
TypeScript client and Next.js pages. The pieces stay small and readable:

```ruby
class Product < GemStack::Model
  field :name, :string, null: false, size: 255     # declared once: validations, request schema,
  field :price, :decimal, null: false               # serializer types and TypeScript all derive from it
  field :description, :text
end

class ProductSerializer < GemStack::Serializer
  attributes :id, :name, :price, :description, :created_at, :updated_at
end

class ProductsController < ApplicationController
  accepts :create, with: Product.input_schema

  def index = render(Product.order(:id))
  def show = render(Product.find(params[:id]))                  # 404 when missing
  def create = render(Product.create(input), status: :created)  # 422 with field errors when invalid
end
```

```ts
// frontend/lib/api/generated — written by `gemstack contract`, never by hand
import { products, type Product } from "@/lib/api/generated";
const created: Product = await products.create({ name: "Lamp", price: "9.99" });
```

## Commands

| Command | |
|---|---|
| `gemstack new NAME` | new app (`--skip-frontend`, `--skip-install`, `--skip-git`) |
| `gemstack dev` | Next.js + Ruby API + gateway on one port |
| `gemstack server` / `s` | the Ruby API alone (Puma) |
| `gemstack routes` | list routes (`-g TEXT` to filter) |
| `gemstack generate resource NAME fields…` / `g` | full vertical slice (`--api-only`, `--frontend-only`, `--actions=`) |
| `gemstack generate model\|migration\|controller …` | smaller generators |
| `gemstack db:create\|migrate\|rollback\|status\|seed\|setup\|reset\|drop` | database |
| `gemstack contract` | regenerate TypeScript types, API client, OpenAPI |
| `gemstack generate job NAME` / `gemstack jobs` | background job / run a worker (`jobs:status`, `jobs:retry`) |
| `gemstack add realtime` | optional realtime module (broadcasts → browsers) |
| `gemstack test` / `t` | run Ruby tests |
| `gemstack console` / `c` | IRB with the app loaded |
| `gemstack version` | |

## Installation

Requirements: **Ruby ≥ 4.0** (developed on 4.0.7), Node.js ≥ 20, npm, and
PostgreSQL (unless `--skip-database`).

```bash
gem install gemstack
gemstack new shop                  # Gemfile: gem "gemstack", "~> 0.1.0"
```

The `gemstack` gem is the framework: it brings every module an app needs
(`gemstack-core`, `-cache`, `-schema`, `-http`, `-contract`, `-dev`, `-cli`).
Optional modules are separate gems added per app — `gemstack-db` and
`gemstack-jobs` by `gemstack new`, `gemstack-realtime`, `-auth`, `-mail` and
`-storage` by `gemstack add …`. All of them are released together with one
version.

**Hacking on GemStack itself?** Clone this repository (every gem lives in
`gems/` and is published from here). `bin/gemstack` runs
the CLI straight from the checkout, and apps it creates point their Gemfile at
the checkout (`path "…/gems"`), so framework changes apply immediately.
`bundle exec rake gems:install` installs the checkout's gems as if released.
Releases: [RELEASING.md](RELEASING.md).

See [`examples/shop`](examples/shop) for a complete example application.

## Repository layout

```text
gems/
  gemstack-core/     config, env, logger, errors, error mapping, inflector, plugins — zero dependencies
  gemstack-cache/    GemStack.cache: memory, null and Redis stores
  gemstack-schema/   shared types, request schemas, serializers
  gemstack-http/     router, middleware, controllers, params, JSON (Rack 3)
  gemstack-db/       PostgreSQL via Sequel: models, migrations, db tasks (optional)
  gemstack-jobs/     background jobs: PostgreSQL queue, adapters, worker
  gemstack-realtime/ GemStack.broadcast → Server-Sent Events (optional: gemstack add realtime)
  gemstack-mail/     mailers, ERB templates, SMTP/log/test delivery, deliver_later
  gemstack-storage/  disk and S3 storage, signed URLs, direct uploads (optional: gemstack add storage)
  gemstack-auth/     Argon2id passwords, sessions, API tokens, policies (optional: gemstack add auth)
  gemstack-contract/ TypeScript types, API clients, OpenAPI from the backend
  gemstack-dev/    dev gateway, process supervisor, file watcher
  gemstack-cli/    `gemstack` command, generators, templates
  gemstack/        umbrella: Application, autoloading, reloading, test helpers
docs/              guides
benchmarks/        performance measurements
ARCHITECTURE.md    design · ROADMAP.md plan · DECISIONS.md decision log · RELEASING.md releases
```

## Developing GemStack

```bash
bundle install
bundle exec rake          # all tests + RuboCop
bundle exec rake test:gemstack-http
GEMSTACK_TEST_DATABASE_URL=postgres://user:pass@localhost/gemstack_test bundle exec rake test:gemstack-db
bundle exec rake bench
```

## Documentation

[Getting started](docs/getting-started.md) ·
[Philosophy](docs/philosophy.md) ·
[Architecture](docs/architecture.md) ·
[Configuration](docs/configuration.md) ·
[Routing](docs/routing.md) ·
[Controllers](docs/controllers.md) ·
[Next.js](docs/nextjs.md) ·
[TypeScript](docs/typescript.md) ·
[Testing](docs/testing.md) ·
[Performance](docs/performance.md) ·
[Deployment](docs/deployment.md) ·
[Resource generation](docs/resource-generation.md)

[Models & database](docs/models.md) · [Validation](docs/validation.md) ·
[Serialization](docs/serialization.md) · [Caching](docs/caching.md) ·
[Background jobs](docs/background-jobs.md) · [Realtime](docs/realtime.md) ·
[Authentication](docs/authentication.md) · [Authorization](docs/authorization.md) ·
[Mail](docs/mail.md) · [Storage](docs/storage.md) · [Development tools](docs/development.md)

## License

MIT
