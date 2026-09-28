# frozen_string_literal: true

require_relative "../gemstack-core/lib/gemstack/version"

Gem::Specification.new do |spec|
  spec.name = "gemstack-jobs"
  spec.version = GemStack::VERSION
  spec.summary = "GemStack background jobs: a PostgreSQL queue by default, swappable adapters"
  spec.authors = ["GemStack contributors"]
  spec.license = "MIT"
  spec.homepage = "https://github.com/gemstack/gemstack"
  spec.required_ruby_version = ">= 4.0"
  spec.files = Dir["lib/**/*.rb"]
  spec.require_paths = ["lib"]
  spec.metadata["rubygems_mfa_required"] = "true"

  # The :postgres adapter uses gemstack-db (loaded on demand), so apps without a
  # database can still use the :async, :inline or :sidekiq adapters.
  spec.add_dependency "gemstack-core", GemStack::VERSION
end
