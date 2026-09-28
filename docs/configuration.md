# Configuration

All configuration goes through one object:

```ruby
# config/app.rb
GemStack.setup(root: File.expand_path("..", __dir__))   # sets the root, loads .env (dev/test)
Bundler.require(:default, GemStack.env.to_sym)

GemStack.configure do |config|
  config.name = "shop"
  config.http.api_path = "/api"
end
```

Per-environment overrides go in `config/environments/<env>.rb` (loaded after
`config/app.rb`). The environment comes from `GEMSTACK_ENV`, then `RACK_ENV`,
defaulting to `development`.

Every setting has a default; setting an unknown name raises `NoMethodError`
immediately (with a "did you mean" suggestion).

## Reference

### Application

| Setting | Default | |
|---|---|---|
| `config.name` | root directory name | |
| `config.root` | `Dir.pwd` | set by the generated `config/app.rb` |
| `config.env_files` | `.env.<env>.local`, `.env.local`, `.env.<env>`, `.env` in dev/test; none in production | earlier files win; real ENV always wins |
| `config.filter_parameters` | password, secret, token, api_key, authorization, cookie, credit_card, cvv, ssn, private_key, … | substring match, masked as `[FILTERED]` in logs |
| `config.reload_code` | `true` in development | reload `app/` + routes on change |
| `config.eager_load` | `true` outside development/test | |
| `config.autoload_paths` | `[]` | extra dirs, e.g. `["lib"]` |

### Logger

| Setting | Default |
|---|---|
| `config.logger.level` | `GEMSTACK_LOG_LEVEL`, else `debug` (`info` in production) |
| `config.logger.format` | `:pretty` in dev/test, `:json` elsewhere |
| `config.logger.output` | `$stdout` (discarded in test unless `GEMSTACK_LOG_LEVEL` is set) |
| `config.logger.color` | auto (TTY) |

Use it anywhere: `GemStack.logger.info("charged", order_id: 1, cents: 500)`.
Replace it entirely with `GemStack.logger = MyLogger.new` (it must respond to
`debug/info/warn/error/fatal`).

### HTTP

| Setting | Default | |
|---|---|---|
| `config.http.api_path` | `"/api"` | routes are relative to it; `""` mounts at root |
| `config.http.health_path` | `"#{api_path}/health"` | `nil` disables |
| `config.http.max_body_size` | 10 MB | 413 beyond |
| `config.http.json` | `:json` | `:oj` or any object with `dump`/`load` |
| `config.http.json_max_nesting` | 64 | |
| `config.http.show_exceptions` | on in development/test | exception details in 500s |
| `config.http.trust_request_id` | `true` | reuse valid incoming `X-Request-Id` |
| `config.http.security_headers` | nosniff, `DENY` framing, referrer policy, COOP, strict CSP | never overrides headers a response sets |
| `config.http.hsts` | 2 years in production | only sent on HTTPS requests |
| `config.http.cors.*` | off (`origins = []`) | `origins`, `methods`, `headers`, `expose_headers`, `credentials`, `max_age` |
| `config.http.middleware` | default stack | see below |

### Compression, ETags, pagination

| Setting | Default |
|---|---|
| `config.http.compression.enabled` | `true` |
| `config.http.compression.min_size` | `1024` bytes |
| `config.http.compression.encodings` | `%w[br gzip]` (Brotli needs the `brotli` gem) |
| `config.http.compression.brotli_quality` / `gzip_level` | `4` / `4` |
| `config.http.etags` | `true` (Rack::ETag + Rack::ConditionalGet) |
| `config.http.pagination.per_page` / `max_per_page` | `25` / `100` |

### Cache (`gemstack-cache`)

| Setting | Default |
|---|---|
| `config.cache.store` | `:memory` (`:null` in test); `:redis` or an object |
| `config.cache.namespace` | the app name |
| `config.cache.default_expires_in` | `nil` (seconds) |
| `config.cache.max_entries` | `10_000` (memory store) |
| `config.cache.redis_url` / `redis_pool_size` | `REDIS_URL` / `GEMSTACK_MAX_THREADS` |

### Runtime

| Setting | Default |
|---|---|
| `config.jit` | `:yjit` in production, `nil` elsewhere; `:zjit` opt-in; `GEMSTACK_JIT=yjit\|zjit\|off` |

### Middleware

```ruby
config.http.middleware.use Rack::Attack
config.http.middleware.insert_before GemStack::HTTP::Middleware::ErrorHandler, MyTiming
config.http.middleware.insert_after 0, Another
config.http.middleware.swap GemStack::HTTP::Middleware::RequestLogger, MyLogger
config.http.middleware.delete GemStack::HTTP::Middleware::SecurityHeaders
config.http.middleware.names # inspect the order
```

Default order: `RequestId`, `RequestLogger`, `Compression`, `ErrorHandler`,
(`Reloader` in development), `SecurityHeaders`, `Cors`, `BodyLimit`,
`HealthCheck`, `ETags`. Each is small and documented in its source file.

### Development server

| Setting | Default |
|---|---|
| `config.dev.port` | `PORT` or 3000 |
| `config.dev.bind` | `127.0.0.1`, `::1` |
| `config.dev.frontend_dir` | `"frontend"` |
| `config.dev.api_command` | `bundle exec puma -C config/puma.rb` |
| `config.dev.frontend_command` | the frontend's `next dev` |
| `config.dev.restart_on` | `config/**/*.rb`, `Gemfile.lock`, `.env*` (except `config/routes.rb`, which reloads in-process) |

### Database (`gemstack-db`)

See [models](models.md#configuration): `config.db.url`, `pool_size`,
`pool_timeout`, `statement_timeout`, `slow_query_ms`, `log_queries`,
`migrations_path`, `seeds_path`, `extensions`, `options`.

### Contract (`gemstack-contract`)

| Setting | Default |
|---|---|
| `config.contract.output_dir` | `frontend/lib/api/generated` |
| `config.contract.openapi_path` | `openapi.json` (`nil` to skip) |
| `config.contract.client_import` | `@/lib/gemstack/client` |
| `config.dev.contract_command` | `bundle exec gemstack contract --quiet` (`nil` disables background regeneration) |
| `config.dev.contract_watch` | `app/**/*.rb`, `config/routes.rb` |

## Extending: error mapping

Give third-party exceptions an HTTP meaning once, for every controller:

```ruby
GemStack::ErrorMapping.register(Stripe::CardError) do |error|
  GemStack::Error.new(error.message, status: 402, code: "card_declined")
end
```

## Extending: plugins

Gems can hook into boot without GemStack knowing about them:

```ruby
GemStack::Config.namespace(:billing) { setting :currency, default: "EUR" }
GemStack::Plugins.register(:billing) do |app|
  app.config.http.middleware.use Billing::Middleware
  app.on_shutdown { Billing.flush }
end
```
