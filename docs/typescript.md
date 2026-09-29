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

const page = await products.list({ page: 2 });          // Paginated<Product>: { data, meta }
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

Paginated actions (`returns :index, GemStack::Page[ProductSerializer]`, which generated
controllers declare) return `Paginated<Product>` and take an optional
`PaginationQuery` (`{ page?, per_page? }`), combined with the action's own query
schema if it has one.

Response conventions without a declaration: `index` → `Product[]`, `show`/`create`/`update` →
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
Decimals are strings so no precision is lost in JavaScript.

## Documenting custom endpoints

The contract — `openapi.json`, the TypeScript types and clients, and the
`/api/docs` page — covers **every route** in `config/routes.rb`, not only
generated resources. A controller written by hand or with
`gemstack g controller` is included as soon as it has a route:

```bash
gemstack contract      # regenerate openapi.json + frontend/lib/api/generated
```

`gemstack dev` runs it for you whenever a file in `app/` or `config/routes.rb`
changes, and `/api/docs` rebuilds on every page load.

What an endpoint takes and returns comes from two declarations in the
controller — add them to custom actions:

```ruby
# config/routes.rb
GemStack.routes do
  get  "/reports/sales",  to: "reports#sales"
  post "/reports/export", to: "reports#export"
end
```

```ruby
# app/serializers/sales_report_serializer.rb
class SalesReportSerializer < ApplicationSerializer
  Report = Data.define(:from, :to, :region, :total)

  attribute :from, :date
  attribute :to, :date
  attribute :region, :string, nullable: true
  attribute :total, :decimal
end
```

```ruby
# app/controllers/reports_controller.rb
class ReportsController < ApplicationController
  # Input: query parameters for GET/DELETE, the JSON body for POST/PATCH/PUT.
  accepts :sales do
    required :from, :date
    required :to, :date
    optional :region, :string
  end
  accepts :export do
    required :format, :string, in: %w[csv xlsx]
  end

  # Output: a serializer, [Serializer] for a list, GemStack::Page[Serializer]
  # for a paginated list, or nil for no body (documented as 204).
  returns :sales, SalesReportSerializer
  returns :export, nil

  def sales
    total = Order.where(created_at: input[:from]..input[:to]).sum(:total) || 0
    report = SalesReportSerializer::Report.new(from: input[:from], to: input[:to], region: input[:region],
                                               total: total)
    render report, serializer: SalesReportSerializer
  end

  def export
    ExportReport.perform_later(input[:format])
    head :no_content
  end
end
```

The result:

- `openapi.json` documents `GET /api/reports/sales` with the query parameters
  `from`, `to` (required) and `region`, and a `SalesReport` response;
  `POST /api/reports/export` with a `ReportExportInput` body and a 204 response.
- The TypeScript client gets typed methods —
  `reports.sales({ from, to, region })` returns `Promise<SalesReport>`.
- `/api/docs` lists both, with a working "Try it" form.

Input types are named `<Resource><Action>Input` (`ReportSalesInput`),
responses after the serializer (`SalesReport`).

**`accepts` validates when the action reads `input`**: an invalid value is a
`422` with field errors at that point, so read `input` (not `params`) in
actions that declare it.

**Without `returns`**, the endpoint is still documented — path, method, path
parameters — but its response type is `unknown`, and `gemstack contract`,
`gemstack doctor` and `/api/docs` show a warning:

```text
warning  ReportsController#summary: response type unknown (add `returns :summary, SomeSerializer`)
```

Conventions spare you `returns` for REST actions named after their resource:
in `ProductsController`, `index` returns `[ProductSerializer]` and `show`,
`create` and `update` return `ProductSerializer`; `destroy` has no body.

## Configuration

```ruby
config.contract.output_dir = "frontend/lib/api/generated"
config.contract.openapi_path = "openapi.json"      # nil to skip
config.contract.client_import = "@/lib/gemstack/client"
config.dev.contract_command = nil                  # disable background regeneration
```

Loading models needs the database to be reachable (Sequel reads table
schemas), but not migrated: types come from `field` declarations.
