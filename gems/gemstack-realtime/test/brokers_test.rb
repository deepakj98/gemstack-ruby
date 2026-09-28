# frozen_string_literal: true

require "test_helper"

# Cross-process brokers against real services.
module BrokerContract
  def receive(timeout = 3) = Timeout.timeout(timeout) { @received.pop }

  def start_broker
    @received = Queue.new
    broker.start { |message| @received << message }
  end

  def test_round_trip
    start_broker
    broker.publish(GemStack::Realtime::Message.new("1-a", "news", "posted", { "n" => 1 }))
    message = receive

    assert_equal ["1-a", "news", "posted", { "n" => 1 }], message.to_a
  end
end

class PostgresBrokerTest < Minitest::Test
  include BrokerContract

  URL = ENV.fetch("GEMSTACK_TEST_DATABASE_URL", nil)

  def setup
    skip "set GEMSTACK_TEST_DATABASE_URL to run the PostgreSQL broker tests" unless URL
    require "gemstack/db"
    GemStack.config.db.url = URL
    GemStack::DB::Tasks.create
  end

  def teardown = @broker&.stop

  def broker = @broker ||= GemStack::Realtime::Brokers::Postgres.new

  def test_broadcasts_are_transactional
    start_broker
    db = GemStack::DB.connection
    db.transaction(rollback: :always) { broker.publish(GemStack::Realtime::Message.new("rb", "news", "x", nil)) }
    db.transaction { broker.publish(GemStack::Realtime::Message.new("ok", "news", "x", nil)) }

    assert_equal "ok", receive.id, "the rolled-back broadcast is never delivered"
  end

  def test_payload_limit
    big = GemStack::Realtime::Message.new("1", "news", "x", { "blob" => "x" * 10_000 })

    error = assert_raises(GemStack::Realtime::PayloadTooLarge) { broker.publish(big) }
    assert_includes error.message, "Redis broker"
  end
end

class RedisBrokerTest < Minitest::Test
  include BrokerContract

  URL = ENV.fetch("GEMSTACK_TEST_REDIS_URL", nil)

  def setup
    skip "set GEMSTACK_TEST_REDIS_URL to run the Redis broker tests" unless URL
  end

  def teardown = @broker&.stop

  def broker = @broker ||= GemStack::Realtime::Brokers::Redis.new(url: URL, channel: "gemstack-test-#{Process.pid}")

  def test_large_payloads_are_fine
    start_broker
    broker.publish(GemStack::Realtime::Message.new("1", "news", "x", { "blob" => "x" * 100_000 }))

    assert_equal 100_000, receive.data["blob"].size
  end
end
