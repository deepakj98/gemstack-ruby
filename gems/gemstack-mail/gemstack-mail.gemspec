# frozen_string_literal: true

require_relative "../gemstack-core/lib/gemstack/version"

Gem::Specification.new do |spec|
  spec.name = "gemstack-mail"
  spec.version = GemStack::VERSION
  spec.summary = "GemStack mail: mailers, templates, SMTP/log/test delivery, deliver_later via jobs"
  spec.authors = ["GemStack contributors"]
  spec.license = "MIT"
  spec.homepage = "https://github.com/gemstack/gemstack"
  spec.required_ruby_version = ">= 4.0"
  spec.files = Dir["lib/**/*.rb"]
  spec.require_paths = ["lib"]
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.add_dependency "erubi", "~> 1.13" # templates, HTML-escaped by default
  spec.add_dependency "gemstack-core", GemStack::VERSION
  spec.add_dependency "mail", "~> 2.9"   # message building and SMTP
end
