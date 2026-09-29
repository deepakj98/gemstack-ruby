# Changelog

All GemStack gems are released together with one version.

## 0.1.0

First release.

- HTTP layer on Rack 3: router, middleware, controllers with `accepts`/`returns`, JSON errors, security defaults
- Single-origin development: `gemstack dev` runs Next.js and the Ruby API behind one port
- PostgreSQL models on Sequel, migrations, validation, serializers
- TypeScript types, typed API clients and OpenAPI generated from the backend; `generate resource` for
  full vertical slices with Next.js pages
- Compression, ETags, pagination, `GemStack.cache`, YJIT by default
- Background jobs on PostgreSQL (transactional, `SKIP LOCKED`, `LISTEN/NOTIFY`), Sidekiq adapter
- Realtime over Server-Sent Events with PostgreSQL fan-out and `useRealtime`
- `gemstack add auth` (Argon2id, cookie sessions, API tokens, password reset, email verification, policies),
  mail, `gemstack add storage` (direct uploads to disk or S3)
- Development error pages, `/api/docs`, `gemstack doctor`, `gemstack generate deploy`
