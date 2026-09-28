# frozen_string_literal: true

module GemStack
  module HTTP
    # One page of a collection, rendered as the pagination envelope
    # (DECISIONS D-034):
    #
    #   { "data": [ ... ], "meta": { "page": 2, "per_page": 25, "total": 180, "total_pages": 8 } }
    #
    # Built by Controller#paginate. `Page[ProductSerializer]` is the matching
    # type for `returns`, so the TypeScript client gets `Page<Product>`.
    class Page
      # Type marker for the contract: Page[ProductSerializer].
      Type = Struct.new(:item)

      def self.[](item_type) = Type.new(item_type)

      attr_reader :items, :page, :per_page, :total

      def initialize(items, page:, per_page:, total:)
        @items = items
        @page = page
        @per_page = per_page
        @total = total
      end

      def total_pages = total.zero? ? 0 : (total.to_f / per_page).ceil

      def meta = { page: page, per_page: per_page, total: total, total_pages: total_pages }
    end
  end
end
