# frozen_string_literal: true

# What the API returns for a Product. Only listed attributes are exposed;
# their types (from Product's fields) drive the generated TypeScript types.
class ProductSerializer < GemStack::Serializer
  attributes :id, :name, :price, :description, :sku, :category_id, :active, :created_at, :updated_at
end
