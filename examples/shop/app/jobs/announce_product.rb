# frozen_string_literal: true

# Runs in the background after a product is created (see ProductsController#create)
# and tells every open products page about it, in realtime.
class AnnounceProduct < GemStack::Job
  queue :announcements
  discard_on GemStack::NotFound # the product was deleted before the job ran

  def perform(product_id)
    product = Product.find(product_id)
    GemStack.logger.info("new product announced", id: product.id, name: product.name)
    # Serialized with ProductSerializer; delivered via PostgreSQL NOTIFY to the API processes.
    GemStack.broadcast("products", "product.created", product)
  end
end
