# frozen_string_literal: true

require_relative "lib/gemstack/version"

Gem::Specification.new do |spec|
  spec.name = "gemstack-core"
  spec.version = GemStack::VERSION
  spec.summary = "GemStack core: configuration, environment, logging, errors and plugins"
  spec.description = "The dependency-free foundation every GemStack module builds on."
  spec.authors = ["GemStack contributors"]
  spec.license = "MIT"
  spec.homepage = "https://github.com/gemstack/gemstack"
  spec.required_ruby_version = ">= 4.0"
  spec.files = Dir["lib/**/*.rb"]
  spec.require_paths = ["lib"]
  spec.metadata["rubygems_mfa_required"] = "true"
end
