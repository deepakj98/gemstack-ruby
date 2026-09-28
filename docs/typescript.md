# TypeScript and the API contract

The backend is the source of truth. `gemstack contract` reads the routes,
controllers' `accepts`/`returns` declarations and serializers, and writes:

```text
frontend/lib/api/generated/
  types.ts        export type Product = {...}; ProductInput; ProductUpdateInput; ...
  products.ts     export const products = { list, get, create, update, delete, search, ... }
  index.ts        re-exports everything
openapi.json      OpenAPI 3.1
```

It runs automatically after `gemstack generate resource`, and in the
background while `gemstack dev` runs whenever `app/` or `config/routes.rb`
changes. Only files whose content changed are rewritten. Generated files start
with a "do not edit" header; hand-written code lives beside them.

## Using the client

```ts
import { products, type Product, type ProductInput } from "@/lib/api/generated";

const list: Product[] = await products.list();
const one = await products.get(42);
const created = await products.create({ name: "Lamp", price: "9.99", sku: "L1", category_id: 1 });
await products.update(42, { price: "12.00" });            // ProductUpdateInput: all optional
await products.delete(42);
await products.search({ q: "lamp" });                     // GET schema → query parameters
```

Every call accepts a final `options` argument (`RequestOptions`: headers,
`cache`, `signal`, ...), and every failure is an `ApiError` (see
[Next.js](nextjs.md)).

## How types are derived

| From | Becomes |
|---|---|
| `ProductSerializer` attributes | `type Product` (response shape) |
| `accepts :create, with: Product.input_schema` | `type ProductInput` (request body) |
| `accepts :update, …, partial: true` | `type ProductUpdateInput` |
| `accepts(:search) { … }` | `type ProductSearchInput` (query for GET) |
| route `GET /products/:id` → `show` | `get: (id: string \| number, options?) => Promise<Product>` |

Response conventions: `index` → `Product[]`, `show`/`create`/`update` →
`Product`, `destroy` → `void`. Declare anything else:

```ruby
returns :search, [ProductSerializer]
returns :stats, StatsSerializer
returns :publish, nil                 # 204, no body
```

Undeclared custom actions are typed `unknown` and reported as warnings.

Optional input fields are `name?: T`; nullable fields are `T | null`. Nested
schemas become inline object types. Shapes are `type` aliases, so they're
assignable to the client's query record type.

Mapping of scalar types: see [serialization](serialization.md#types-and-output-format).
Decimals are strings so no precision is lost in JavaScript (DECISIONS D-022).

## Configuration

```ruby
config.contract.output_dir = "frontend/lib/api/generated"
config.contract.openapi_path = "openapi.json"      # nil to skip
config.contract.client_import = "@/lib/gemstack/client"
config.dev.contract_command = nil                  # disable background regeneration
```

Loading models needs the database to be reachable (Sequel reads table
schemas), but not migrated: types come from `field` declarations.
