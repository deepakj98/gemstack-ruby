# Deployment

A GemStack app is two processes:

```bash
# Ruby API (Puma, config/puma.rb)
GEMSTACK_ENV=production GEMSTACK_API_PORT=4000 WEB_CONCURRENCY=2 bundle exec puma -C config/puma.rb
# or: gemstack server -e production -p 4000

# Next.js
cd frontend && npm ci && npm run build && npm start
```

Run background job workers as a third process type (scale them
independently; any number can share the queue):

```bash
GEMSTACK_ENV=production DATABASE_URL=… bundle exec gemstack jobs -c 10
```

Run migrations on each release, before starting the new API processes:

```bash
GEMSTACK_ENV=production DATABASE_URL=… bundle exec gemstack db:migrate
```

Production defaults: JSON logs with request IDs, no exception details in
responses, eager loading, HSTS on HTTPS requests, `.env` files not loaded
(use real environment variables for secrets).

## Choose how `/api` reaches Ruby

The browser always calls same-origin `/api/...`, so pick one:

### 1. Reverse proxy (recommended)

Route `/api/*` to Puma and everything else to Next.js, e.g. Caddy:

```caddy
example.com {
  handle /api/* {
    reverse_proxy 127.0.0.1:4000
  }
  handle {
    reverse_proxy 127.0.0.1:3000
  }
}
```

Best for WebSockets and streaming; API traffic doesn't pass through Node.

### 2. Next.js rewrites (no extra infrastructure)

The generated `next.config.ts` proxies `/api/*` to `GEMSTACK_API_URL` when it
is set. Deploy Next.js publicly and the API privately:

```bash
cd frontend
GEMSTACK_API_URL=http://api.internal:4000 npm run build   # rewrites are fixed at build time
GEMSTACK_API_URL=http://api.internal:4000 npm start       # also used by Server Components
```

> **Set `GEMSTACK_API_URL` at build time.** Next.js evaluates `rewrites()` during
> `next build`; changing it only at runtime does not change the rewrite target.

Server-Sent Events work through rewrites; WebSockets need option 1.

### 3. Separate domains

If the API must live on `api.example.com`:

```ruby
# config/environments/production.rb
config.http.cors.origins = ["https://example.com"]
```

and build the frontend with `NEXT_PUBLIC_GEMSTACK_API_URL=https://api.example.com`.

## Checklist

- `GEMSTACK_ENV=production` and `DATABASE_URL` for the API; `db:migrate` on release.
- PostgreSQL connections: `WEB_CONCURRENCY × GEMSTACK_MAX_THREADS` per host (pool per worker).
- Terminate TLS at the proxy and forward `X-Forwarded-Proto` (HSTS depends on it).
- `WEB_CONCURRENCY` ≈ CPU cores, `GEMSTACK_MAX_THREADS` 3–5.
- YJIT is enabled automatically in production (`config.jit`); nothing to set.
- Add `gem "brotli"` for Brotli compression; with a compressing CDN/proxy in front, either is fine
  (GemStack never re-compresses encoded responses).
- Several processes/hosts? Use `config.cache.store = :redis` (`gem "redis-client"`, `REDIS_URL`).
- Realtime (SSE) works through Next.js rewrites and reverse proxies; with nginx set
  `proxy_read_timeout` above 15 s (GemStack sends `X-Accel-Buffering: no`). See docs/realtime.md.
- `SECRET_KEY_BASE` (`openssl rand -hex 64`) — needed by storage signatures and any module using
  `GemStack.key_for`; keep it stable across deploys.
- With auth: `SMTP_URL`, `MAIL_FROM` and `APP_URL` (the frontend's public URL, for email links); run a
  jobs worker (emails are sent from jobs); serve over HTTPS (the session cookie is `Secure`); call
  `GemStack::Auth.cleanup!` daily; use the Redis cache store with several hosts so rate limits are shared.
- With storage: `STORAGE_SERVICE=s3`, `S3_BUCKET`, `AWS_REGION` (+ credentials), `gem "aws-sdk-s3"`, and
  a bucket CORS rule allowing `PUT` from your site (docs/storage.md).
- Health check: `GET /api/health` → `200 {"status":"ok"}`.
- Collect stdout: each line is a JSON object with `level`, `msg`, `id`.

Deployment recipes (Docker, Fly, Render, Railway) are planned for Phase 7.
