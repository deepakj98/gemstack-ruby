# Resource generation

```bash
gemstack generate resource Product name:string price:decimal description:text:optional \
                                   sku:string:unique category:references active:boolean
gemstack db:migrate
```

produces a complete vertical slice:

```text
db/migrations/<ts>_create_products.rb     table, NOT NULL/unique constraints, FK + index
app/models/product.rb                     field declarations, uniqueness, belongs_to
app/serializers/product_serializer.rb     what the API returns
app/controllers/products_controller.rb    index show create update destroy, `accepts` schemas
config/routes.rb                          resources :products
test/models/product_test.rb               validity, required fields
test/controllers/products_controller_test.rb   every action, 404, 422
frontend/lib/api/generated/*              types + typed client (via `gemstack contract`)
frontend/lib/queries/products.ts          TanStack Query hooks (useProducts, useCreateProduct, …)
frontend/components/products/             ProductForm, ProductTable, ProductCard
frontend/app/products/                    list, new, [id], [id]/edit pages
```

Run without fields to be asked interactively (fields, full CRUD?, Next.js
pages?, tests?).

## Fields

`name:type[:modifier...]`

| Types | `string text integer bigint float decimal boolean date datetime uuid json references` |
|---|---|
| Modifiers | `optional` (nullable), `unique`, `index` |

Fields are **required** (NOT NULL + "is required") unless `:optional`
(DECISIONS D-025). Booleans are `NOT NULL DEFAULT false`. `category:references`
creates `category_id` with a foreign key (`ON DELETE RESTRICT`), an index and
`belongs_to :category`.

## Modes

| Option | Generates |
|---|---|
| *(default)* / `--crud` | everything, all five REST actions |
| `--actions=index,show` | only those actions (routes use `only:`; pages/forms/hooks follow) |
| `--api-only` | migration, model, serializer, controller, routes, tests |
| `--frontend-only` | Next.js pages, components and hooks for an existing backend resource |
| `--skip-tests` | no test files |
| `--skip-contract` | don't run `gemstack contract` afterwards |
| `--force` | overwrite existing files |

Existing files are never overwritten silently (identical files are reported
as such), and routes are not added twice.

## Other generators

```bash
gemstack generate model Product name:string price:decimal       # migration + model + serializer + test
gemstack generate migration AddSkuToProducts sku:string:unique  # alter_table with add_column/add_index
gemstack generate migration BackfillPrices                      # empty migration
gemstack generate controller Reports summary export             # controller + test + routes
```

## Generated tests

Tests build valid records from the model's field declarations at runtime:

```ruby
Product.create(GemStack::DB::Testing.sample_attributes(Product))
post_json "/api/products", GemStack::DB::Testing.sample_payload(Product)
```

So they keep passing as fields change. `references` fields create the referenced
record; fields with a `format:` rule may need an override
(`sample_attributes(Product, sku: "ABC")`).

## Customising templates

Every template can be replaced per app. Copy it to
`lib/templates/gemstack/<generator>/` with the same relative path:

```text
lib/templates/gemstack/resource/controller/app/controllers/%plural%_controller.rb.tt
lib/templates/gemstack/resource/frontend/frontend/components/%url_segment%/%class_name%Form.tsx.tt
lib/templates/gemstack/controller/app/controllers/%file_name%_controller.rb.tt
```

Parts: `resource/{migration,model,serializer,controller,frontend}`, `controller`,
`migration`. Templates are ERB (`.tt`); `%name%` path segments are substituted
from the resource spec (`file_name`, `plural`, `class_name`, `url_segment`, `table`, `timestamp`).
