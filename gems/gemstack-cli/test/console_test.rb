# frozen_string_literal: true

require "test_helper"

class ConsoleTest < Minitest::Test
  def test_reload_helper_delegates_to_application
    application = Object.new
    calls = 0

    application.define_singleton_method(:reload!) do
      calls += 1
      true
    end

    GemStack.define_singleton_method(:application) { application }

    TOPLEVEL_BINDING.eval <<~RUBY
      def reload!
        GemStack.application.reload!
      end
    RUBY

    assert_equal true, TOPLEVEL_BINDING.eval("reload!")
    assert_equal 1, calls
  end
end
