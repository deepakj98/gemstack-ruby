# frozen_string_literal: true

module GemStack
  module Realtime
    module Brokers
      # Records broadcasts for assertions (the default in tests); see
      # GemStack::Realtime::Testing.
      class Test
        attr_reader :messages

        def initialize
          @messages = []
          @mutex = Mutex.new
        end

        def start(&on_message)
          @on_message = on_message
          self
        end

        def publish(message)
          @mutex.synchronize { @messages << message }
          @on_message&.call(message)
        end

        def clear = @mutex.synchronize { @messages.clear }
        def stop = @on_message = nil
      end
    end
  end
end
