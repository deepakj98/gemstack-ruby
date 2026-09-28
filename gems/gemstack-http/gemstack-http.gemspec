# frozen_string_literal: true

require_relative "../gemstack-core/lib/gemstack/version"

Gem::Specification.new do |spec|
  spec.name = "gemstack-http"
  spec.version = GemStack::VERSION
  spec.summary = "GemStack HTTP: router, middleware, controllers, params and JSON for Rack"
  spec.description = "The API layer of GemStack, built on Rack 3."
  spec.authors = ["GemStack contributors"]
  spec.license = "MIT"
  spec.homepage = "https://github.com/gemstack/gemstack"
  spec.required_ruby_version = ">= 4.0"
  spec.files = Dir["lib/**/*.rb"]
  spec.require_paths = ["lib"]
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.add_dependency "gemstack-core", GemStack::VERSION
  spec.add_dependency "gemstack-schema", GemStack::VERSION
  spec.add_dependency "json", ">= 2.10" # JSON::Coder
  spec.add_dependency "rack", "~> 3.1"
end
