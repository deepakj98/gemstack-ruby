# frozen_string_literal: true

require_relative "../gemstack-core/lib/gemstack/version"

Gem::Specification.new do |spec|
  spec.name = "gemstack-auth"
  spec.version = GemStack::VERSION
  spec.summary = "GemStack auth: Argon2id passwords, cookie sessions, API tokens, policies"
  spec.authors = ["GemStack contributors"]
  spec.license = "MIT"
  spec.homepage = "https://github.com/gemstack/gemstack"
  spec.required_ruby_version = ">= 4.0"
  spec.files = Dir["lib/**/*.rb"]
  spec.require_paths = ["lib"]
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.add_dependency "argon2", "~> 2.3"
  spec.add_dependency "gemstack-cache", GemStack::VERSION
  spec.add_dependency "gemstack-core", GemStack::VERSION
  spec.add_dependency "gemstack-db", GemStack::VERSION
  spec.add_dependency "gemstack-http", GemStack::VERSION
  spec.add_dependency "gemstack-mail", GemStack::VERSION
  # Verifying legacy bcrypt hashes needs bcrypt in the app's Gemfile (optional).
end
