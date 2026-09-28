# Serialization

Serializers decide exactly what the API returns. **Nothing is exposed unless
it is listed** — rendering a model without a serializer is an error, not a dump
of every column.

```ruby
class ProductSerializer < GemStack::Serializer
  attributes :id, :name, :price, :active, :created_at      # types inferred from Product's fields

  attribute :display_price, :string do |product|           # computed; typed explicitly
    "€#{product.price.to_s("F")}"
  end

  attribute :category, CategorySerializer                  # nested object
  attribute :reviews, [ReviewSerializer]                   # nested list
  attribute :internal_note, :text, nullable: true
end
```

## Rendering

```ruby
render product                         # finds ProductSerializer by convention
render Product.where(active: true)     # datasets and arrays → lists
render product, serializer: Admin::ProductSerializer
```

Blocks run in the serializer instance, with the object as their argument and
`context` available. Controllers pass `serializer_context` as the context:

```ruby
class ApplicationController < GemStack::Controller
  private

  def serializer_context = { current_user: current_user }
end
```

Use a serializer directly: `ProductSerializer.serialize(product)`,
`ProductSerializer.many(products)`.

## Types and output format

| Type | JSON | TypeScript |
|---|---|---|
| `string`, `text`, `uuid` | string | `string` |
| `integer`, `bigint`, `float`, `references` | number | `number` |
| `decimal` | string (exact: `"9.99"`) | `string` |
| `boolean` | boolean | `boolean` |
| `date` | `"2026-09-28"` | `string` |
| `datetime` | `"2026-09-28T09:35:59.697Z"` (UTC, ms) | `string` |
| `json` | as is | `unknown` |

Attribute types come from, in order: the explicit type, the model's `field`
declaration (the model is found by name: `ProductSerializer` → `Product`,
override with `model SomeModel`), then conventions (`id`, `created_at`,
`updated_at`). Nullability follows the model field (`null: false` → not
nullable); explicitly typed attributes are non-null unless `nullable: true`.
Untyped attributes appear as `unknown` in TypeScript, and `gemstack contract`
prints a warning for each.
