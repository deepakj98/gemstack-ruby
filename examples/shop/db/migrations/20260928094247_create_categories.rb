# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:categories) do
      primary_key :id, type: :Bignum
      String :name, null: false, unique: true
      column :created_at, :timestamptz, null: false
      column :updated_at, :timestamptz, null: false
    end
  end
end
