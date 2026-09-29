# frozen_string_literal: true

# All GemStack gems share one version; change it with `rake version:set[x.y.z]`.
version = "0.2.5"

Gem::Specification.new do |spec|
  spec.name = "gemstack"
  spec.version = version
  spec.summary = "GemStack: a fast, modular Ruby API framework for Next.js applications"
  spec.authors = ["Adware Technologies", "Shoaib Malik"]
  spec.email = ["gemstack26@gmail.com"]
  spec.license = "MIT"
  spec.homepage = "https://github.com/gemstack-rb/gemstack"
  spec.required_ruby_version = ">= 3.3"
  spec.files = Dir["README.md", "LICENSE.txt", "CHANGELOG.md", "lib/**/*.rb"]
  spec.require_paths = ["lib"]
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["source_code_uri"] = "https://github.com/gemstack-rb/gemstack/tree/main/gems/gemstack"
  spec.metadata["changelog_uri"] = "https://github.com/gemstack-rb/gemstack/blob/main/gems/gemstack/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/gemstack-rb/gemstack/issues"
  spec.metadata["documentation_uri"] = "https://github.com/gemstack-rb/gemstack/tree/main/docs"

  spec.add_dependency "gemstack-cache", version
  spec.add_dependency "gemstack-cli", version
  spec.add_dependency "gemstack-contract", version
  spec.add_dependency "gemstack-core", version
  spec.add_dependency "gemstack-dev", version
  spec.add_dependency "gemstack-http", version
  spec.add_dependency "gemstack-schema", version
  spec.add_dependency "puma", ">= 6.4"
  spec.add_dependency "zeitwerk", "~> 2.6"
end
