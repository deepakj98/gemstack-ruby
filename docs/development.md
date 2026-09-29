# Development tools

## `gemstack doctor`

Checks that the app can run and says how to fix what can't:

```text
$ gemstack doctor
GemStack doctor · shop

  ✓ Ruby 4.0.7 (YJIT available)
  ✓ Node.js 22.11.0
  ✓ frontend dependencies installed
  ✓ application boots (development, 12 routes)
  ✗ database: database "shop_development" does not exist
      → run: gemstack db:create
  ✓ port 3000 is free for gemstack dev

1 problem(s)
```

It checks Ruby (and `.ruby-version`), Node.js (20.9+ for Next.js 16), the
frontend's `node_modules`, secret files tracked by git (`.env`, keys), that
the app boots, the database (and where its settings come from), pending
migrations, the jobs table, Redis (when the cache uses it), the realtime
broker (SQLite/MySQL apps with a jobs worker need Redis for it), whether the generated TypeScript is up to date, and the
dev port. It exits with status 1 when something is broken, so it fits CI.

`gemstack doctor --production` also checks what a deploy needs —
`SECRET_KEY_BASE` (length included), a production database (and a reminder
about SQLite's single-server limits), `SMTP_URL` and `APP_URL`
with auth, `S3_BUCKET` and `aws-sdk-s3` with S3 storage, `REDIS_URL` with the
Redis cache. Run it where the production environment variables are set, e.g.
`docker compose run --rm api bundle exec gemstack doctor --production`.

## Error pages

In development, when a **browser** opens an API URL that raises (a 500), you
get an HTML page: the exception, the lines of your code around the failure,
and the backtrace with your frames highlighted and gem paths shortened.
`fetch()`, the generated client and `curl` still get the JSON error envelope —
with the exception's class, message and backtrace under `exception` — and
the TypeScript client prints that to the browser console next to the failing
request:

```text
[GemStack API] GET /products/7 → Sequel::DatabaseError: PG::UndefinedColumn: …
  app/controllers/products_controller.rb:12:in 'ProductsController#show'
```

Both come from `config.http.show_exceptions`, which is on in development and
test only. Production responses never contain messages of server errors or
backtraces.

## API docs: `/api/docs`

`gemstack dev` serves interactive API docs at
[http://localhost:3000/api/docs](http://localhost:3000/api/docs): every route
grouped by controller, parameters, request and response types (as TypeScript,
matching the generated client), contract warnings, and a **Try it** form that
sends the request from the page — with your session cookie, so sign in through
the app first to call protected endpoints.

The page is built from the live routes on every load (no `gemstack contract`
needed) — custom controllers included; declare `accepts` and `returns` so
their types show ([documenting custom endpoints](typescript.md#documenting-custom-endpoints)) — and is self-contained: no CDN, no external requests. The OpenAPI
document behind it is at `/api/docs/openapi.json`; `gemstack contract` also
writes it to `openapi.json` for other tools.

It is on in development only (`config.contract.docs`); in production
`/api/docs` is a 404, because a public list of your endpoints helps attackers
more than users.
