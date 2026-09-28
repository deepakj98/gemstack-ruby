# frozen_string_literal: true

require_relative "../test_helper"

class CategoryTest < GemStack::TestCase
  def sample = GemStack::DB::Testing.sample_attributes(Category)

  def test_valid_with_sample_attributes
    category = Category.new(sample)

    assert_predicate category, :valid?, category.errors.to_h.inspect
  end

  def test_create
    category = Category.create(sample)

    assert category.id
    assert category.created_at
  end

  def test_requires_name
    category = Category.new(sample.except(:name))

    refute_predicate category, :valid?
    assert_includes category.errors[:name], "is required"
  end
end
