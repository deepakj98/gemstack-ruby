# frozen_string_literal: true

# A minimal GemStack app for end-to-end server benchmarks (benchmarks/server_bench.sh).
$LOAD_PATH.unshift(*Dir[File.expand_path("../../gems/*/lib", __dir__)])
ENV["GEMSTACK_ENV"] ||= "production"
require "gemstack"

Product = Struct.new(:id, :name, :price, :description, :active, :created_at)
PRODUCTS = Array.new(20) do |i|
  Product.new(i, "Product #{i}", BigDecimal("#{i}.99"), "Something useful, number #{i}", i.even?, Time.utc(2026, 1, 1))
end.freeze

class ProductSerializer < GemStack::Serializer
  attributes id: :bigint, name: :string, price: :decimal, description: :text, active: :boolean, created_at: :datetime
end

class ProductsController < GemStack::Controller
  def index = render(PRODUCTS)
end

GemStack.configure do |config|
  config.root = __dir__
  config.logger.level = :warn
end
GemStack.routes { get "/products", to: "products#index" }

run GemStack.boot!
