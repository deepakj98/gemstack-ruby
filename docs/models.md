# Models and the database

GemStack models are [Sequel](https://sequel.jeremyevans.net) models on
SQLite, PostgreSQL or MySQL — connecting, `config/database.yml`,
adapters and `db:*` commands are in [databases](database.md). API-only apps
without a database use `gemstack new NAME --skip-database`.

The connection is lazy: the app boots even when the database is down, and
requests then fail with `503 service_unavailable`. The pool size follows
Puma's thread count (`GEMSTACK_MAX_THREADS`, default 5); Puma's `before_fork`
disconnects before forking workers.

```bash
gemstack generate migration AddSkuToProducts sku:string:unique
```

## Migrations

Plain, timestamped Sequel migrations in `db/migrations/`:

```ruby
Sequel.migration do
  change do
    create_table(:products) do
      primary_key :id, type: :Bignum
      String :name, null: false
      BigDecimal :price, size: [12, 2], null: false
      foreign_key :category_id, :categories, type: :Bignum, null: false, on_delete: :restrict
      column :created_at, :timestamptz, null: false
      column :updated_at, :timestamptz, null: false
      index :category_id
    end
  end
end
```

See Sequel's [schema modification guide](https://sequel.jeremyevans.net/rdoc/files/doc/schema_modification_rdoc.html).

## Defining models

Models inherit from `ApplicationModel` (`app/models/application_model.rb`,
created by `gemstack new`), the place for plugins and helpers every model
shares; it is a `GemStack::Model`, which is a `Sequel::Model`. It is defined
with `ApplicationModel = Class.new(GemStack::Model)` so Sequel doesn't bind it
to an `application_models` table — keep that line as it is.

```ruby
class Product < ApplicationModel
  field :name, :string, null: false, size: 120
  field :price, :decimal, null: false, gt: 0
  field :description, :text
  field :active, :boolean, null: false, default: false
  field :category_id, :references, null: false

  validates :name, format: /\A\S/, length: { min: 2 }
  validates :sku, uniqueness: true

  belongs_to :category        # many_to_one
  has_many :reviews           # one_to_many
end
```

`field` declares what the application knows about a column. Declaring a field
once gives you:

- **validations**: `null: false` → "is required"; `size:` → max length;
  `gt/gte/lt/lte`, `in:`, `format:`;
- **a request schema**: `Product.input_schema` (see [validation](validation.md));
- **serializer types**, and so **TypeScript types**.

The table itself comes from migrations. Types: `string text integer bigint
float decimal boolean date datetime uuid json references`.

`validates` adds rules: `presence`, `length: { min:, max: }`, `format`,
`inclusion: { in: }`, `numericality: { gt:, ... }`, `uniqueness`. Custom rules
use Sequel's hook:

```ruby
def validate
  super
  errors.add(:price, "must be a round number") if price && price % 1 != 0
end
```

Timestamps (`created_at`, `updated_at`) are set automatically when the
columns exist. Use `GemStack::Model(:inventory_items)` for a table that
doesn't match the class name.

## Querying

Everything in Sequel works:

```ruby
Product.find(42)                       # raises 404 RecordNotFound when missing ("abc" too)
Product.find_by(sku: "LAMP-1")         # nil when missing;  find_by! raises 404
Product.where(active: true).order(:name).limit(20).all
Product.where { price > 100 }.count
Product.create(name: "Lamp", price: "9.99")     # raises 422 on validation failure (alias create!)
product.update(price: 12)                       # alias update!
product.destroy
GemStack.db[:products].where(active: false).delete  # the Sequel::Database
GemStack.transaction { order.save; payment.save }   # nested calls become savepoints
```

Queries are always parameterised; build conditions with hashes or Sequel's
expression DSL, and escape user input for `LIKE` with `GemStack.db.dataset.escape_like`.

## Errors

Database errors become the standard envelope automatically:

| Situation | Response |
|---|---|
| `find` / `first!` without a row | 404 `not_found` |
| model validation fails | 422 `validation_failed`, `errors: { field: [...] }` |
| unique constraint | 422, `{ "sku": ["is already taken"] }` |
| NOT NULL constraint | 422, `{ "name": ["is required"] }` |
| foreign key to a missing row | 422, `{ "category_id": ["does not exist"] }` |
| deleting a row that is still referenced | 409 `still_referenced` |
| database unreachable / pool exhausted | 503 |

## Rendering

Models are never serialized implicitly — rendering one without a serializer
raises a clear error. Define `ProductSerializer` (see [serialization](serialization.md)).

## Configuration

```ruby
config.db.url = ENV["DATABASE_URL"]
config.db.pool_size = 10
config.db.statement_timeout = 5_000   # ms
config.db.slow_query_ms = 500         # WARN log above this
config.db.log_queries = true          # SQL at DEBUG (default in development)
config.db.extensions = %i[pg_json pg_array]
config.db.options = { sslmode: "require" }   # passed to Sequel.connect
```
