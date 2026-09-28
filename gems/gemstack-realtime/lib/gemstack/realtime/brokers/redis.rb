# frozen_string_literal: true

module GemStack
  module Realtime
    module Brokers
      # Fan-out through Redis pub/sub (add `gem "redis-client"`). Use it for
      # large payloads or very high broadcast rates. Broadcasts inside a
      # database transaction are published after commit.
      class Redis
        def initialize(url: Realtime.config.redis_url, channel: Realtime.config.redis_channel)
          require "redis-client"
          @config = RedisClient.config(url: url)
          @channel = channel
          @publisher = @config.new_pool(size: 5, timeout: 1.0)
        rescue LoadError
          raise ConfigurationError, 'the Redis realtime broker needs `gem "redis-client"` in the Gemfile'
        end

        def publish(message)
          after_commit { @publisher.call("PUBLISH", @channel, message.json) }
        end

        def start(&on_message)
          @running = true
          ready = Queue.new
          @thread = Thread.new { listen(on_message, ready) }
          ready.pop(timeout: 5)
          self
        end

        def stop
          @running = false
          @thread&.join(2)
        end

        private

        def listen(on_message, ready)
          while @running
            begin
              pubsub = @config.new_client.pubsub
              pubsub.call("SUBSCRIBE", @channel)
              ready << true
              while @running
                event = pubsub.next_event(1) or next
                deliver(on_message, event[2]) if event[0] == "message"
              end
            rescue RedisClient::Error => e
              GemStack.logger.warn("realtime: Redis subscription failed, retrying", error: e.message)
              sleep 1
            ensure
              pubsub&.close
            end
          end
        end

        def deliver(on_message, payload)
          on_message.call(Message.from_json(payload))
        rescue StandardError => e
          GemStack.logger.error("realtime: delivery failed", error: e)
        end

        def after_commit(&)
          db = defined?(GemStack::DB) && GemStack::DB.connected? ? GemStack::DB.connection : nil
          db&.in_transaction? ? db.after_commit(&) : yield
        end
      end
    end
  end
end
