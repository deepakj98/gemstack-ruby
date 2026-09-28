# frozen_string_literal: true

require_relative "../test_helper"

class CategoriesControllerTest < GemStack::TestCase
  # Valid values derived from Category's field declarations — edit freely.
  def create_category = Category.create(GemStack::DB::Testing.sample_attributes(Category))
  def payload = GemStack::DB::Testing.sample_payload(Category)

  def test_index
    create_category
    get_json "/api/categories"

    assert_status 200
    assert_equal 1, json_body["data"].size
    assert_equal({ "page" => 1, "per_page" => 25, "total" => 1, "total_pages" => 1 }, json_body["meta"])
  end

  def test_show
    category = create_category
    get_json "/api/categories/#{category.id}"

    assert_status 200
    assert_equal category.id, json_body["id"]
  end

  def test_show_missing
    get_json "/api/categories/0"

    assert_error 404, "not_found"
  end

  def test_create
    post_json "/api/categories", payload

    assert_status 201
    assert Category[json_body["id"]]
  end

  def test_create_with_invalid_input
    post_json "/api/categories", {}

    assert_error 422, "validation_failed"
    assert_equal ["is required"], json_body["errors"]["name"]
  end

  def test_update
    category = create_category
    patch_json "/api/categories/#{category.id}", payload

    assert_status 200
    assert_equal category.id, json_body["id"]
  end

  def test_destroy
    category = create_category
    delete_json "/api/categories/#{category.id}"

    assert_status 204
    assert_nil Category[category.id]
  end
end
