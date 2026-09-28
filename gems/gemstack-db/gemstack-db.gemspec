# frozen_string_literal: true

require_relative "../gemstack-core/lib/gemstack/version"

Gem::Specification.new do |spec|
  spec.name = "gemstack-db"
  spec.version = GemStack::VERSION
  spec.summary = "GemStack database: Sequel models, migrations and PostgreSQL defaults"
  spec.authors = ["GemStack contributors"]
  spec.license = "MIT"
  spec.homepage = "https://github.com/gemstack/gemstack"
  spec.required_ruby_version = ">= 4.0"
  spec.files = Dir["lib/**/*.rb"]
  spec.require_paths = ["lib"]
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.add_dependency "gemstack-core", GemStack::VERSION
  spec.add_dependency "gemstack-schema", GemStack::VERSION
  spec.add_dependency "pg", ">= 1.5"
  spec.add_dependency "sequel", "~> 5.80"
end
