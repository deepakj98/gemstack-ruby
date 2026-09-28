# frozen_string_literal: true

class ProductsController < ApplicationController
  accepts :create, with: Product.input_schema
  accepts :update, with: Product.input_schema, partial: true

  # A hand-written endpoint next to the generated CRUD. `accepts` validates
  # the query string; `returns` types it for the generated TypeScript client.
  accepts(:search) { required :q, :string, min_length: 2 }
  returns :search, [ProductSerializer]

  # GET /api/products/search?q=lamp
  def search
    pattern = "%#{GemStack.db.dataset.escape_like(input[:q])}%"
    render Product.where(Sequel.ilike(:name, pattern)).order(:name).limit(20)
  end

  # GET /api/products
  def index
    render Product.order(:id)
  end

  # GET /api/products/:id
  def show
    render Product.find(params[:id])
  end

  # POST /api/products
  def create
    render Product.create(input), status: :created
  end

  # PATCH /api/products/:id
  def update
    product = Product.find(params[:id])
    product.update(input)
    render product
  end

  # DELETE /api/products/:id
  def destroy
    Product.find(params[:id]).destroy
    head :no_content
  end
end
