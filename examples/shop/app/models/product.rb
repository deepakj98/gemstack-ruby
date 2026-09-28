# frozen_string_literal: true

class Product < GemStack::Model
  field :name, :string, null: false, size: 255
  field :price, :decimal, null: false
  field :description, :text
  field :sku, :string, null: false, size: 255
  field :category_id, :references, null: false
  field :active, :boolean, null: false, default: false

  validates :sku, uniqueness: true

  belongs_to :category
end
