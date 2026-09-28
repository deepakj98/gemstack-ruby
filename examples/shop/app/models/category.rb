# frozen_string_literal: true

class Category < GemStack::Model
  field :name, :string, null: false, size: 255

  validates :name, uniqueness: true

  has_many :products
end
