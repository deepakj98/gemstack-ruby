# frozen_string_literal: true

ENV["GEMSTACK_ENV"] = "test"
require "gemstack/realtime"
require "gemstack/realtime/testing"
require "minitest/autorun"
require "socket"
require "timeout"
require "puma"

GemStack.config.logger.output = nil

# Reads Server-Sent Events from a raw socket.
class SSEClient
  attr_reader :status, :headers

  def initialize(port, query, headers = {})
    @socket = TCPSocket.new("127.0.0.1", port)
    extra = headers.map { |k, v| "#{k}: #{v}\r\n" }.join
    @socket.write("GET /api/realtime?#{query} HTTP/1.1\r\nHost: localhost\r\n#{extra}\r\n")
    @buffer = +""
    head = read_until("\r\n\r\n")
    lines = head.split("\r\n")
    @status = lines.first.split[1].to_i
    @headers = lines[1..].to_h { |line| line.split(": ", 2).then { |k, v| [k.downcase, v] } }
  end

  # The next event (a Hash of SSE fields; "data" parsed as JSON), skipping comments.
  def next_event(timeout = 3)
    Timeout.timeout(timeout) do
      loop do
        block = read_until("\n\n")
        fields = block.lines.map(&:chomp).reject { |l| l.start_with?(":") }.to_h { |l| l.split(": ", 2) }
        next if fields.empty? || fields.keys == ["retry"]

        fields["data"] = JSON.parse(fields["data"]) if fields["data"]
        return fields
      end
    end
  end

  def raw(timeout = 3) = Timeout.timeout(timeout) { read_until("\n\n") }
  def body_rest = @buffer
  def close = @socket.close

  private

  def read_until(separator)
    until (index = @buffer.index(separator))
      @buffer << @socket.readpartial(4096)
    end
    part = @buffer[0...index]
    @buffer = @buffer[(index + separator.size)..]
    part
  end
end

# Boots a real Puma server around a GemStack HTTP app with the realtime middleware.
module RealtimeServer
  def start_server(threads: 2)
    config = GemStack::HTTP::Config.new
    config.middleware.insert_before(GemStack::HTTP::Middleware::HealthCheck, GemStack::Realtime::Middleware,
                                    path: "/api/realtime")
    router = GemStack::HTTP::Router.new(prefix: "/api").draw do
      get "/slow", to: ->(_) { sleep 0.2 and [200, {}, ["slow"]] }
    end
    app = GemStack::HTTP::App.new(config: config, router: router)
    @server = Puma::Server.new(app, nil, min_threads: threads, max_threads: threads)
    @server.add_tcp_listener("127.0.0.1", 0)
    @port = @server.connected_ports.first
    @server.run
  end

  def stop_server
    @clients&.each { |c| c.close rescue nil } # rubocop:disable Style/RescueModifier
    @server&.stop(true)
    GemStack::Realtime.reset!
    GemStack::Realtime::Streamer.reset!
  end

  def connect(query, headers = {})
    (@clients ||= []) << SSEClient.new(@port, query, headers)
    @clients.last
  end

  def wait_until(timeout = 3)
    deadline = Time.now + timeout
    sleep 0.02 until yield || Time.now > deadline
    yield
  end
end
