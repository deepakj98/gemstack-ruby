# frozen_string_literal: true

# `gemstack db:seed` — safe to run more than once.
lighting = Category.find_by(name: "Lighting") || Category.create(name: "Lighting")
desks = Category.find_by(name: "Desks") || Category.create(name: "Desks")

[
  { name: "Desk lamp", price: "39.90", sku: "LAMP-001", category_id: lighting.id, active: true },
  { name: "Floor lamp", price: "89.00", sku: "LAMP-002", category_id: lighting.id, active: true },
  { name: "Standing desk", price: "549.00", sku: "DESK-001", category_id: desks.id, active: false,
    description: "Electric, height adjustable." }
].each { |attrs| Product.find_by(sku: attrs[:sku]) || Product.create(attrs) }
