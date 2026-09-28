# frozen_string_literal: true

require "minitest"
require "rack/test"
require "json"

module GemStack
  # Test helpers for GemStack applications (Minitest + rack-test).
  #
  #   class ProductsTest < GemStack::TestCase
  #     def test_index
  #       get_json "/api/products"
  #       assert_status 200
  #       assert_equal [], json_body
  #     end
  #   end
  module Testing
    module Helpers
      include Rack::Test::Methods

      def app = GemStack.application

      # Parsed JSON body of the last response.
      def json_body
        JSON.parse(last_response.body)
      end

      def get_json(path, params = {}, headers = {})
        get(path, params, json_headers(headers))
      end

      %w[post put patch delete].each do |verb|
        define_method(:"#{verb}_json") do |path, body = {}, headers = {}|
          public_send(verb, path, JSON.generate(body),
                      json_headers(headers).merge("CONTENT_TYPE" => "application/json"))
        end
      end

      def assert_status(expected, message = nil)
        expected = Rack::Utils::SYMBOL_TO_STATUS_CODE.fetch(expected) if expected.is_a?(Symbol)
        message ||= "Expected status #{expected}, got #{last_response.status}: #{last_response.body[0, 500]}"
        assert_equal expected, last_response.status, message
      end

      # assert_error 422, "validation_failed"
      def assert_error(status, code = nil)
        assert_status status
        assert_equal code, json_body.dig("error", "code") if code
      end

      private

      def json_headers(headers) = { "HTTP_ACCEPT" => "application/json" }.merge(headers)
    end
  end

  class TestCase < Minitest::Test
    include Testing::Helpers
  end
end
