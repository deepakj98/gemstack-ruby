# frozen_string_literal: true

require_relative "../test_helper"

class ProductsControllerTest < GemStack::TestCase
  # Valid values derived from Product's field declarations — edit freely.
  def create_product = Product.create(GemStack::DB::Testing.sample_attributes(Product))
  def payload = GemStack::DB::Testing.sample_payload(Product)

  def test_index
    create_product
    get_json "/api/products"

    assert_status 200
    assert_equal 1, json_body["data"].size
    assert_equal({ "page" => 1, "per_page" => 25, "total" => 1, "total_pages" => 1 }, json_body["meta"])
  end

  def test_show
    product = create_product
    get_json "/api/products/#{product.id}"

    assert_status 200
    assert_equal product.id, json_body["id"]
  end

  def test_show_missing
    get_json "/api/products/0"

    assert_error 404, "not_found"
  end

  def test_create
    post_json "/api/products", payload

    assert_status 201
    assert Product[json_body["id"]]
    assert_enqueued AnnounceProduct, args: [json_body["id"]]
  end

  def test_create_with_invalid_input
    post_json "/api/products", {}

    assert_error 422, "validation_failed"
    assert_equal ["is required"], json_body["errors"]["name"]
  end

  def test_update
    product = create_product
    patch_json "/api/products/#{product.id}", payload

    assert_status 200
    assert_equal product.id, json_body["id"]
  end

  def test_destroy
    product = create_product
    delete_json "/api/products/#{product.id}"

    assert_status 204
    assert_nil Product[product.id]
  end

  def test_search
    create_product.update(name: "Brass desk lamp")
    get_json "/api/products/search", { q: "desk" }

    assert_status 200
    assert_equal(["Brass desk lamp"], json_body.map { |p| p["name"] })
  end

  def test_search_requires_a_query
    get_json "/api/products/search", { q: "x" }

    assert_error 422, "validation_failed"
    assert_equal ["is too short (minimum 2 characters)"], json_body["errors"]["q"]
  end

  def test_show_is_cacheable_with_etags
    product = create_product
    get_json "/api/products/#{product.id}"
    etag = last_response.headers["etag"]

    get_json "/api/products/#{product.id}", {}, { "HTTP_IF_NONE_MATCH" => etag }

    assert_status 304
    product.update(name: "Renamed")
    get_json "/api/products/#{product.id}", {}, { "HTTP_IF_NONE_MATCH" => etag }

    assert_status 200
  end
end
