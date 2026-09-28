# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:products) do
      primary_key :id, type: :Bignum
      String :name, null: false
      BigDecimal :price, size: [12, 2], null: false
      String :description, text: true
      String :sku, null: false, unique: true
      foreign_key :category_id, :categories, type: :Bignum, null: false, on_delete: :restrict
      TrueClass :active, null: false, default: false
      column :created_at, :timestamptz, null: false
      column :updated_at, :timestamptz, null: false

      index :category_id
    end
  end
end
