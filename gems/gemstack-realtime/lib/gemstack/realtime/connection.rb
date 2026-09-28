# frozen_string_literal: true

module GemStack
  module Realtime
    # One browser's event stream on a hijacked socket. #push never blocks:
    # bytes the socket can't take yet are buffered and flushed by the
    # Streamer when it becomes writable. A client more than max_buffer bytes
    # behind is disconnected (it reconnects and replays or refetches).
    class Connection
      attr_reader :io, :channels

      def initialize(io, channels, streamer:, max_buffer: Realtime.config.max_buffer)
        @io = io
        @channels = channels.freeze
        @streamer = streamer
        @max_buffer = max_buffer
        @buffer = String.new(encoding: Encoding::BINARY)
        @mutex = Mutex.new
        @closed = false
      end

      def closed? = @closed
      def pending? = @mutex.synchronize { !@buffer.empty? }

      def push(bytes)
        wants_write = @mutex.synchronize do
          return false if @closed

          @buffer << bytes.b
          if @buffer.bytesize > @max_buffer
            GemStack.logger.warn("realtime: slow client disconnected", buffered: @buffer.bytesize)
            close_locked
            return false
          end
          !flush_locked
        end
        @streamer.want_write(self) if wants_write
        true
      end

      # Writes as much as the socket accepts. Returns true when fully flushed.
      def flush = @mutex.synchronize { @closed || flush_locked }

      def close
        @mutex.synchronize { close_locked }
      end

      private

      def flush_locked
        until @buffer.empty?
          written = @io.write_nonblock(@buffer, exception: false)
          return false if written == :wait_writable

          @buffer = @buffer.byteslice(written, @buffer.bytesize) || String.new(encoding: Encoding::BINARY)
        end
        true
      rescue IOError, SystemCallError
        close_locked
        true
      end

      def close_locked
        return if @closed

        @closed = true
        @buffer.clear
        @io.close unless @io.closed?
        @streamer.closed(self)
      rescue IOError, SystemCallError
        nil
      end
    end
  end
end
