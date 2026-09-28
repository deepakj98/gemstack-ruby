# frozen_string_literal: true

require_relative "../gemstack-core/lib/gemstack/version"

Gem::Specification.new do |spec|
  spec.name = "gemstack-realtime"
  spec.version = GemStack::VERSION
  spec.summary = "GemStack realtime: GemStack.broadcast to browsers over Server-Sent Events"
  spec.authors = ["GemStack contributors"]
  spec.license = "MIT"
  spec.homepage = "https://github.com/gemstack/gemstack"
  spec.required_ruby_version = ">= 4.0"
  spec.files = Dir["lib/**/*.rb"]
  spec.require_paths = ["lib"]
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.add_dependency "gemstack-core", GemStack::VERSION
  spec.add_dependency "gemstack-http", GemStack::VERSION
  spec.add_dependency "gemstack-schema", GemStack::VERSION
  # The event loop that serves long-lived connections off the server's request
  # threads (the same library Puma uses).
  spec.add_dependency "nio4r", "~> 2.7"
end
