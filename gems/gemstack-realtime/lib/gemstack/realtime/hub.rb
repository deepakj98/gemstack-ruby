# frozen_string_literal: true

module GemStack
  module Realtime
    # This process's subscriptions and replay history. The broker's listener
    # calls #deliver; connections are only ever written to without blocking.
    class Hub
      Entry = Struct.new(:message, :at)

      def initialize(replay_size: Realtime.config.replay_size, replay_ttl: Realtime.config.replay_ttl)
        # Identity sets: a subscriber is the same subscriber however its state changes.
        @subscriptions = Hash.new { |hash, key| hash[key] = Set.new.compare_by_identity }
        @history = []
        @replay_size = replay_size
        @replay_ttl = replay_ttl
        @mutex = Mutex.new
      end

      def add(connection)
        @mutex.synchronize { connection.channels.each { |channel| @subscriptions[channel] << connection } }
        connection
      end

      def remove(connection)
        @mutex.synchronize do
          connection.channels.each do |channel|
            subscribers = @subscriptions[channel]
            subscribers.delete(connection)
            @subscriptions.delete(channel) if subscribers.empty?
          end
        end
      end

      def connections = @mutex.synchronize { @subscriptions.values.flat_map(&:to_a).uniq(&:object_id) }

      def subscriber_count(channel)
        @mutex.synchronize { @subscriptions.key?(channel) ? @subscriptions[channel].size : 0 }
      end

      def deliver(message)
        subscribers = @mutex.synchronize do
          @history << Entry.new(message, monotonic)
          @history.shift while @history.size > @replay_size
          @subscriptions.key?(message.channel) ? @subscriptions[message.channel].to_a : []
        end
        payload = message.sse
        subscribers.each { |connection| connection.push(payload) }
        subscribers.size
      end

      # Events on `channels` published after the event with id `last_id`.
      # Returns [messages, gap]; gap is true when last_id is no longer in the
      # history, so the client may have missed events and should refetch.
      def replay(channels, last_id)
        return [[], false] if last_id.nil? || last_id.empty?

        @mutex.synchronize do
          cutoff = monotonic - @replay_ttl
          @history.reject! { |entry| entry.at < cutoff }
          index = @history.rindex { |entry| entry.message.id == last_id }
          return [[], true] unless index

          [@history[(index + 1)..].map(&:message).select { |m| channels.include?(m.channel) }, false]
        end
      end

      def shutdown
        connections.each(&:close)
      end

      private

      def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
