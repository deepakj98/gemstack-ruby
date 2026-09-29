# frozen_string_literal: true

require_relative "../gemstack-core/lib/gemstack/version"

Gem::Specification.new do |spec|
  spec.name = "gemstack-contract"
  spec.version = GemStack::VERSION
  spec.summary = "GemStack contract: TypeScript types, API clients and OpenAPI from the backend"
  spec.authors = ["GemStack contributors"]
  spec.license = "MIT"
  spec.homepage = "https://github.com/gemstack/gemstack"
  spec.required_ruby_version = ">= 4.0"
  spec.files = Dir["lib/**/*.{rb,html}"]
  spec.require_paths = ["lib"]
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.add_dependency "gemstack-core", GemStack::VERSION
  spec.add_dependency "gemstack-http", GemStack::VERSION
  spec.add_dependency "gemstack-schema", GemStack::VERSION
end
