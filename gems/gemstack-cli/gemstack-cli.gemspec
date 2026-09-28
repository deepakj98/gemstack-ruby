# frozen_string_literal: true

require_relative "../gemstack-core/lib/gemstack/version"

Gem::Specification.new do |spec|
  spec.name = "gemstack-cli"
  spec.version = GemStack::VERSION
  spec.summary = "GemStack command-line interface and generators"
  spec.authors = ["GemStack contributors"]
  spec.license = "MIT"
  spec.homepage = "https://github.com/gemstack/gemstack"
  spec.required_ruby_version = ">= 4.0"
  spec.files = Dir["lib/**/*.rb", "templates/**/*", "templates/**/.*", "exe/*"]
  spec.require_paths = ["lib"]
  spec.bindir = "exe"
  spec.executables = ["gemstack"]
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.add_dependency "gemstack-core", GemStack::VERSION
  spec.add_dependency "gemstack-dev", GemStack::VERSION
  spec.add_dependency "thor", "~> 1.3"
end
