# frozen_string_literal: true

module GemStack
  module Realtime
    module Brokers
      # Delivers within the current process only (the default without a
      # database). Broadcasts made inside a database transaction are sent
      # after it commits, like with the PostgreSQL broker.
      class Memory
        def start(&on_message)
          @on_message = on_message
          self
        end

        def publish(message)
          after_commit { @on_message&.call(message) }
        end

        def stop = @on_message = nil

        private

        def after_commit(&)
          db = defined?(GemStack::DB) && GemStack::DB.connected? ? GemStack::DB.connection : nil
          db&.in_transaction? ? db.after_commit(&) : yield
        end
      end
    end
  end
end
