# frozen_string_literal: true

require_relative "../gemstack-core/lib/gemstack/version"

Gem::Specification.new do |spec|
  spec.name = "gemstack"
  spec.version = GemStack::VERSION
  spec.summary = "GemStack: a fast, modular Ruby API framework for Next.js applications"
  spec.authors = ["GemStack contributors"]
  spec.license = "MIT"
  spec.homepage = "https://github.com/gemstack/gemstack"
  spec.required_ruby_version = ">= 4.0"
  spec.files = Dir["lib/**/*.rb"]
  spec.require_paths = ["lib"]
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.add_dependency "gemstack-cache", GemStack::VERSION
  spec.add_dependency "gemstack-cli", GemStack::VERSION
  spec.add_dependency "gemstack-contract", GemStack::VERSION
  spec.add_dependency "gemstack-core", GemStack::VERSION
  spec.add_dependency "gemstack-dev", GemStack::VERSION
  spec.add_dependency "gemstack-http", GemStack::VERSION
  spec.add_dependency "gemstack-schema", GemStack::VERSION
  spec.add_dependency "puma", ">= 6.4"
  spec.add_dependency "zeitwerk", "~> 2.6"
end
