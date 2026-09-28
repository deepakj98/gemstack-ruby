# frozen_string_literal: true

# Phase 3 measurements: serialization, JSON codecs, compression levels,
# cache hits and the cost of the new middleware. In-process, no network.
# Run with `bundle exec rake bench` (or `ruby --yjit benchmarks/payload_bench.rb`).

$LOAD_PATH.unshift(*Dir[File.expand_path("../gems/*/lib", __dir__)])
ENV["GEMSTACK_ENV"] = "production"
require "gemstack/http"
require "gemstack/cache"
require "benchmark"
require "zlib"
require "brotli"
require "oj"

GemStack.config.logger.output = nil

def measure(label, iterations, &)
  GC.start
  allocations = GC.stat(:total_allocated_objects)
  seconds = Benchmark.realtime { iterations.times(&) }
  per_call = (GC.stat(:total_allocated_objects) - allocations) / iterations.to_f
  puts format("%<label>-50s %<us>9.2f µs/op %<allocs>9.1f allocs/op",
              label: label, us: seconds / iterations * 1_000_000, allocs: per_call)
end

Product = Struct.new(:id, :name, :price, :description, :active, :created_at)

class ProductSerializer < GemStack::Serializer
  attributes id: :bigint, name: :string, price: :decimal, active: :boolean, created_at: :datetime
  attribute :description, :text, nullable: true
end

products = Array.new(100) do |i|
  Product.new(i, "Product #{i}", BigDecimal("#{i}.99"), i.even? ? "A useful thing" : nil, true, Time.utc(2026, 1, 1))
end
jit = if defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled? then "YJIT"
      elsif defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled? then "ZJIT"
      else "interpreter"
      end
puts "GemStack #{GemStack::VERSION} · Ruby #{RUBY_VERSION} (#{jit}) · json #{JSON::VERSION} · oj #{Oj::VERSION}"

puts "\n-- serialization"
measure("serializer: 20 records", 20_000) { ProductSerializer.many(products.first(20)) }
measure("serializer: 100 records", 5_000) { ProductSerializer.many(products) }

puts "\n-- JSON encode (serializer output)"
stdlib = GemStack::HTTP::JSONCodec::Stdlib.new
oj = GemStack::HTTP::JSONCodec::Oj.new
page20 = ProductSerializer.many(products.first(20))
page100 = ProductSerializer.many(products)
measure("json stdlib: 20 records", 50_000) { stdlib.dump(page20) }
measure("json oj (strict fast path): 20 records", 50_000) { oj.dump(page20) }
measure("json stdlib: 100 records", 10_000) { stdlib.dump(page100) }
measure("json oj (strict fast path): 100 records", 10_000) { oj.dump(page100) }
raw = { time: Time.now, price: BigDecimal("1.5"), items: [1, 2, 3] }
measure("json stdlib: non-native values (Time, BigDecimal)", 50_000) { stdlib.dump(raw) }
measure("json oj (fallback): non-native values", 50_000) { oj.dump(raw) }

puts "\n-- compression of a 100-record JSON response (#{stdlib.dump(page100).bytesize} bytes)"
body = stdlib.dump(page100)
{ "gzip 1" => -> { Zlib.gzip(body, level: 1) }, "gzip 6 (default)" => -> { Zlib.gzip(body, level: 6) },
  "gzip 9" => -> { Zlib.gzip(body, level: 9) }, "brotli 1" => -> { Brotli.deflate(body, quality: 1) },
  "brotli 4 (default)" => -> { Brotli.deflate(body, quality: 4) },
  "brotli 6" => -> { Brotli.deflate(body, quality: 6) },
  "brotli 11 (max)" => -> { Brotli.deflate(body, quality: 11) } }.each do |label, compress|
  size = compress.call.bytesize
  iterations = label.include?("11") ? 200 : 2_000
  measure("#{label}: #{size} bytes (#{(100.0 * size / body.bytesize).round(1)}%)", iterations) { compress.call }
end

puts "\n-- cache"
cache = GemStack::Cache::MemoryStore.new(namespace: "bench")
cache.write("page", page20)
measure("memory cache hit (20 serialized records)", 50_000) { cache.fetch("page") { raise } }
cache.write("n", 1)
measure("memory cache hit (integer)", 200_000) { cache.read("n") }

puts "\n-- request cost of the Phase 3 middleware (index, 20 records)"
class ProductsController < GemStack::HTTP::Controller
  ITEMS = Array.new(20) { |i| { id: i, name: "Product #{i}", price: "#{i}.99", active: true } }.freeze
  def index = render(ITEMS)
end
router = GemStack::HTTP::Router.new(prefix: "/api", resolver: ->(_) { ProductsController })
router.draw { get "/products", to: "products#index" }
build = lambda do |**toggles|
  config = GemStack::HTTP::Config.new
  config.compression.enabled = toggles.fetch(:compression, true)
  config.etags = toggles.fetch(:etags, true)
  GemStack::HTTP::App.new(config: config, router: router)
end
call = lambda do |app, env|
  _, _, response = app.call(env)
  response.each { |_| next }
  response.close if response.respond_to?(:close)
end
plain = ->(**headers) { Rack::MockRequest.env_for("/api/products", **headers) }
bare = build.call(compression: false, etags: false)
etags = build.call(compression: false)
full = build.call
measure("no compression, no etags", 20_000) { call.call(bare, plain.call) }
measure("+ etags", 20_000) { call.call(etags, plain.call) }
measure("+ etags + compression (client without Accept-Encoding)", 20_000) { call.call(full, plain.call) }
measure("+ etags + gzip response", 20_000) { call.call(full, plain.call("HTTP_ACCEPT_ENCODING" => "gzip")) }
measure("+ etags + brotli response", 20_000) { call.call(full, plain.call("HTTP_ACCEPT_ENCODING" => "br")) }
