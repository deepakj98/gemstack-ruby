# frozen_string_literal: true

# What the API returns for a Category. Only listed attributes are exposed;
# their types (from Category's fields) drive the generated TypeScript types.
class CategorySerializer < GemStack::Serializer
  attributes :id, :name, :created_at, :updated_at

  # Computed attributes are typed explicitly; this one becomes `product_count: number` in TypeScript.
  attribute :product_count, :integer do |category|
    category.products_dataset.count
  end
end
