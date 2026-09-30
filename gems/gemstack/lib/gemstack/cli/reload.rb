# frozen_string_literal: true

module GemStack
  class CLI < Thor
    no_commands do
      def define_reload!
        TOPLEVEL_BINDING.eval <<~RUBY
          def reload!
            GemStack.application.reload!
          end
        RUBY
      end
    end
  end
end
