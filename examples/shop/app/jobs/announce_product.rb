# frozen_string_literal: true

# Runs in the background after a product is created (see ProductsController#create).
# Phase 5 will push this to connected browsers as a realtime notification.
class AnnounceProduct < GemStack::Job
  queue :announcements
  discard_on GemStack::NotFound # the product was deleted before the job ran

  def perform(product_id)
    product = Product.find(product_id)
    GemStack.logger.info("new product announced", id: product.id, name: product.name, price: product.price.to_s("F"))
  end
end
