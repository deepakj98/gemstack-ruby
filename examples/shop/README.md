# Shop — a GemStack example

A small catalogue built to show GemStack end to end. It was created with the
CLI, then extended by hand:

```bash
gemstack new shop
gemstack generate resource Category name:string:unique
gemstack generate resource Product name:string price:decimal description:text:optional \
                                   sku:string:unique category:references active:boolean
```

## What it demonstrates

| Feature | Where |
|---|---|
| PostgreSQL models with `field` declarations, validations, associations | `app/models/` |
| Migrations | `db/migrations/` |
| Explicit serializers (+ a computed, typed attribute) | `app/serializers/category_serializer.rb` |
| Generated CRUD API with `accepts` request schemas | `app/controllers/` |
| A hand-written endpoint: `GET /api/products/search?q=` with `accepts` + `returns` | `ProductsController#search` |
| Consistent errors: 422 field errors, unique/FK violations, 404, 409 | try the API below |
| Generated TypeScript types + typed API client (`products.search({ q })`) | `frontend/lib/api/generated/` |
| TanStack Query hooks, React state, URL state (`?q=`) | `frontend/lib/queries/`, `components/products/ProductSearch.tsx` |
| Next.js pages and components per resource | `frontend/app/products/`, `frontend/components/products/` |
| Transactional tests with sample data from field declarations | `test/` |
| OpenAPI 3.1 | `openapi.json` |
| Background job enqueued in the same transaction as the product | `app/jobs/announce_product.rb`, `ProductsController#create` |
| Realtime: the job broadcasts, open products pages update live | `config/channels.rb`, `components/products/NewProductNotice.tsx` |

## Run it

Requires PostgreSQL. Point the app at a database you can create:

```bash
cd examples/shop
cat > .env <<'ENV'
DATABASE_URL=postgres://USER:PASSWORD@localhost:5432/shop_development
TEST_DATABASE_URL=postgres://USER:PASSWORD@localhost:5432/shop_test
ENV
bundle install && (cd frontend && npm install)
bin/gemstack db:setup      # create, migrate, seed
bin/gemstack dev           # http://localhost:3000
bin/gemstack test
```

Try the API through the single origin:

```bash
curl localhost:3000/api/products/search?q=lamp
curl -X POST localhost:3000/api/products -H 'content-type: application/json' -d '{"price":"-1"}'
# {"error":{"code":"validation_failed",...},"errors":{"name":["is required"],"sku":["is required"],"category_id":["is required"]}}
```
