# frozen_string_literal: true

class CategoriesController < ApplicationController
  returns :index, Page[CategorySerializer]
  accepts :create, with: Category.input_schema
  accepts :update, with: Category.input_schema, partial: true

  # GET /api/categories?page=1&per_page=25
  def index
    render paginate(Category.order(:id))
  end

  # GET /api/categories/:id
  def show
    render Category.find(params[:id])
  end

  # POST /api/categories
  def create
    render Category.create(input), status: :created
  end

  # PATCH /api/categories/:id
  def update
    category = Category.find(params[:id])
    category.update(input)
    render category
  end

  # DELETE /api/categories/:id
  def destroy
    Category.find(params[:id]).destroy
    head :no_content
  end
end
