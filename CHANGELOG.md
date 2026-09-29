# Changelog

All GemStack gems are released together with one version.

## 0.2.0

Databases: SQLite, PostgreSQL and MySQL, configured by `config/database.yml`.

- Rails-style `config/database.yml` (per environment, ERB); `config.db.url`, then `DATABASE_URL`
  (`TEST_DATABASE_URL` in tests), then the file
- Adapters: SQLite (`sqlite3`), PostgreSQL (`pg`), MySQL 8 (`mysql2` or `trilogy`);
  `gemstack new --database=sqlite3|postgresql|mysql2|trilogy`, SQLite by default
- Portable migrations: `timestamptz`, `jsonb`, `uuid`, `inet` map to native types on MySQL and SQLite;
  times stored in UTC; SQLite in WAL mode with a busy timeout
- The job queue, auth, storage, `gemstack doctor` and `gemstack generate deploy` work on every adapter;
  realtime fans out through Redis when the database isn't PostgreSQL
- Constraint errors become field errors on MySQL and SQLite too

### Upgrading from 0.1.0

- `gemstack-db` no longer depends on `pg`. Add the driver to your Gemfile: `gem "pg", "~> 1.5"`.
- Apps without `config/database.yml` keep using PostgreSQL `<app>_<env>` or `DATABASE_URL`, as before.
  Adding the file is optional (`docs/database.md`).
- `config.jobs.adapter = :postgres` still works; the new name is `:database`.

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
