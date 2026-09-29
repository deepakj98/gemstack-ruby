# Pagination

List endpoints return one page of records at a time. The client asks for a
page with `?page=` and `?per_page=`; the API answers with the records and
where it is in the list.

## In a controller

```ruby
class ProductsController < ApplicationController
  returns :index, GemStack::Page[ProductSerializer]   # tells the TypeScript contract the shape

  def index = render(paginate(Product.order(:id)))
end
```

Generated resources (`gemstack g resource`) already look like this.

`paginate(scope)` reads `page` and `per_page` from the query string, loads
just that page (`LIMIT` / `OFFSET`), counts the total, and `render` sends:

```http
GET /api/products?page=2&per_page=3
```

```json
{
  "data": [
    { "id": 4, "name": "Desk" },
    { "id": 5, "name": "Chair" },
    { "id": 6, "name": "Lamp" }
  ],
  "meta": { "page": 2, "per_page": 3, "total": 137, "total_pages": 46 }
}
```

| Request | Result |
| --- | --- |
| `GET /api/products` | page 1, 25 records (the default `per_page`) |
| `?page=3` | page 3 |
| `?per_page=50` | 50 records per page |
| `?per_page=5000` | capped at `max_per_page` (100) — never an unbounded response |
| `?page=0`, `?per_page=abc` | `422` with field errors |
| a page after the last | `200` with `"data": []` |

Always **order** the dataset (`.order(:id)`, `.order(Sequel.desc(:created_at))`):
without an order the database may return rows in any order, and a record can
show up on two pages or none. `paginate` also takes arrays.

## Changing the number of records per page

There are three levels; the more specific one wins.

**1. For the whole app** — `config/app.rb` (or one environment in
`config/environments/*.rb`):

```ruby
GemStack.configure do |config|
  config.http.pagination.per_page = 50        # when the client doesn't send per_page (default 25)
  config.http.pagination.max_per_page = 200   # the most a client may ask for (default 100)
end
```

**2. For one action** — the default for this endpoint only:

```ruby
def index = render(paginate(Product.order(:id), per_page: 10))
```

The client can still ask for another size with `?per_page=`, up to
`max_per_page`.

**3. For one request** — from the client:

```http
GET /api/products?page=1&per_page=12
```

## In the Next.js frontend

The generated client knows the shape: `list` takes `{ page?, per_page? }`
(`PaginationQuery`) and returns `Paginated<Product>`:

```ts
import { products } from "@/lib/api/generated";

const result = await products.list({ page: 2, per_page: 12 });
result.data;               // Product[]
result.meta.total_pages;   // number
```

The generated TanStack Query hook takes the page and, optionally, the size:

```tsx
const { data } = useProducts(page);        // the API's default per_page
const { data } = useProducts(page, 12);    // 12 per page
```

It keeps the current page visible while the next one loads
(`placeholderData: keepPreviousData`), and the generated list page shows
previous/next buttons from `meta`.

## Paginating other queries

`paginate` works on any Sequel dataset, so filters, joins and scopes come
first:

```ruby
def index
  scope = Product.where(active: true).order(:name)
  scope = scope.where(Sequel.ilike(:name, "%#{params[:q]}%")) if params[:q]
  render paginate(scope)
end
```

With authorization, paginate what the policy allows:
`render paginate(policy_scope(Order.order(:id)))`.

A custom serializer: `render paginate(scope), serializer: Admin::ProductSerializer`
(and `returns :index, GemStack::Page[Admin::ProductSerializer]`).

## Large tables

Offset pagination runs a `COUNT(*)` and an `OFFSET` query, so pages far into a
very large table get slower. For infinite scroll or "load more" over big
tables, use a cursor instead — a plain query and a plain array:

```ruby
accepts(:index) { optional :after, :integer }
returns :index, [ProductSerializer]

def index
  scope = Product.order(:id).limit(50)
  scope = scope.where(Sequel[:id] > input[:after]) if input[:after]
  render scope.all
end
```

The client passes the last `id` it has as `?after=`.
