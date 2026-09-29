# frozen_string_literal: true

# All GemStack gems share one version; change it with `rake version:set[x.y.z]`.
version = "0.2.1"

Gem::Specification.new do |spec|
  spec.name = "gemstack-dev"
  spec.version = version
  spec.summary = "GemStack development server: single-origin gateway and process supervisor"
  spec.authors = ["Shoaib Malik"]
  spec.email = ["gemstack26@gmail.com"]
  spec.license = "MIT"
  spec.homepage = "https://github.com/gemstack-rb/gemstack"
  spec.required_ruby_version = ">= 4.0"
  spec.files = Dir["README.md", "LICENSE.txt", "CHANGELOG.md", "lib/**/*.rb"]
  spec.require_paths = ["lib"]
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["source_code_uri"] = "https://github.com/gemstack-rb/gemstack/tree/main/gems/gemstack-dev"
  spec.metadata["changelog_uri"] = "https://github.com/gemstack-rb/gemstack/blob/main/gems/gemstack-dev/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/gemstack-rb/gemstack/issues"
  spec.metadata["documentation_uri"] = "https://github.com/gemstack-rb/gemstack/tree/main/docs"

  spec.add_dependency "gemstack-core", version
end
