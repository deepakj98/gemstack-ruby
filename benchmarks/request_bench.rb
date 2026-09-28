# frozen_string_literal: true

# Measures the in-process cost of GemStack's request path (no network, no
# server): routing alone, and a full request through the default middleware
# stack, a controller and JSON rendering. Run with `bundle exec rake bench`.

$LOAD_PATH.unshift(*Dir[File.expand_path("../gems/*/lib", __dir__)])
ENV["GEMSTACK_ENV"] = "production"
require "gemstack/http"
require "benchmark"

GemStack.config.logger.output = nil

class ProductsController < GemStack::HTTP::Controller
  PRODUCTS = Array.new(20) { |i| { id: i, name: "Product #{i}", price: "9.99", active: true } }.freeze

  def index = render(PRODUCTS)
  def show = render(PRODUCTS[params[:id].to_i % 20])
end

def build_router
  router = GemStack::HTTP::Router.new(prefix: "/api", resolver: ->(_) { ProductsController })
  router.draw do
    # 100 resources ≈ 600 routes, so lookups aren't flattered by a tiny table.
    100.times { |i| resources :"things#{i}" }
    resources :products, only: %i[index show]
  end
end

def measure(label, iterations, &)
  GC.start
  allocations = GC.stat(:total_allocated_objects)
  seconds = Benchmark.realtime { iterations.times(&) }
  per_call = (GC.stat(:total_allocated_objects) - allocations) / iterations.to_f
  puts format("%<label>-44s %<ops>10.0f ops/s %<us>8.2f µs/op %<allocs>8.1f allocs/op",
              label: label, ops: iterations / seconds, us: seconds / iterations * 1_000_000, allocs: per_call)
end

router = build_router
config = GemStack::HTTP::Config.new
app = GemStack::HTTP::App.new(config: config, router: router)
bare_config = GemStack::HTTP::Config.new
bare_config.middleware = GemStack::HTTP::MiddlewareStack.new
bare = GemStack::HTTP::App.new(config: bare_config, router: router)
env_for = ->(path) { Rack::MockRequest.env_for(path) }
call = lambda do |rack_app, env|
  _status, _headers, body = rack_app.call(env)
  body.each { |_| next }
  body.close if body.respond_to?(:close)
end

puts "GemStack #{GemStack::VERSION} · Ruby #{RUBY_VERSION} · #{router.routes.size} routes · JSON #{JSON::VERSION}"
n = 200_000
measure("router: static path (/api/products)", n) { router.recognize("GET", "/api/products") }
measure("router: dynamic path (/api/products/:id)", n) { router.recognize("GET", "/api/products/42") }
measure("router: miss", n) { router.recognize("GET", "/api/nope/1/2") }

n = 50_000
measure("request: health check (middleware only)", n) { call.call(app, env_for.call("/api/health")) }
measure("request: show, no middleware", n) { call.call(bare, env_for.call("/api/products/3")) }
measure("request: show, default middleware", n) { call.call(app, env_for.call("/api/products/3")) }
measure("request: index (20 records), default stack", n) { call.call(app, env_for.call("/api/products")) }

codec = GemStack::HTTP::JSONCodec::Stdlib.new
payload = ProductsController::PRODUCTS
measure("json: dump 20 records (stdlib)", n) { codec.dump(payload) }
begin
  oj = GemStack::HTTP::JSONCodec::Oj.new
  measure("json: dump 20 records (oj)", n) { oj.dump(payload) }
rescue LoadError
  puts "json: oj not installed, skipped"
end
