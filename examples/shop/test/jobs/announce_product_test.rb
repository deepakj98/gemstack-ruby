# frozen_string_literal: true

require_relative "../test_helper"

class AnnounceProductTest < GemStack::TestCase
  def test_announces_an_existing_product
    product = Product.create(GemStack::DB::Testing.sample_attributes(Product))

    perform_enqueued_jobs { AnnounceProduct.perform_later(product.id) }
  end

  def test_a_deleted_product_is_discarded_not_retried
    outcomes = perform_enqueued_jobs { AnnounceProduct.perform_later(0) }

    assert_equal [:discarded], outcomes.map(&:status)
  end
end
