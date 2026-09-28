# frozen_string_literal: true

require_relative "../test_helper"

class ProductTest < GemStack::TestCase
  def sample = GemStack::DB::Testing.sample_attributes(Product)

  def test_valid_with_sample_attributes
    product = Product.new(sample)

    assert_predicate product, :valid?, product.errors.to_h.inspect
  end

  def test_create
    product = Product.create(sample)

    assert product.id
    assert product.created_at
  end

  def test_requires_name
    product = Product.new(sample.except(:name))

    refute_predicate product, :valid?
    assert_includes product.errors[:name], "is required"
  end

  def test_requires_price
    product = Product.new(sample.except(:price))

    refute_predicate product, :valid?
    assert_includes product.errors[:price], "is required"
  end

  def test_requires_sku
    product = Product.new(sample.except(:sku))

    refute_predicate product, :valid?
    assert_includes product.errors[:sku], "is required"
  end

  def test_requires_category_id
    product = Product.new(sample.except(:category_id))

    refute_predicate product, :valid?
    assert_includes product.errors[:category_id], "is required"
  end
end
