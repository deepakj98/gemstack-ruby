# frozen_string_literal: true

# All GemStack gems share one version; change it with `rake version:set[x.y.z]`.
version = "0.1.0"

Gem::Specification.new do |spec|
  spec.name = "gemstack-mail"
  spec.version = version
  spec.summary = "GemStack mail: mailers, templates, SMTP/log/test delivery, deliver_later via jobs"
  spec.authors = ["Shoaib Malik"]
  spec.email = ["gemstack26@gmail.com"]
  spec.license = "MIT"
  spec.homepage = "https://github.com/gemstack-rb/gemstack"
  spec.required_ruby_version = ">= 4.0"
  spec.files = Dir["README.md", "LICENSE.txt", "CHANGELOG.md", "lib/**/*.rb"]
  spec.require_paths = ["lib"]
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["source_code_uri"] = "https://github.com/gemstack-rb/gemstack/tree/main/gems/gemstack-mail"
  spec.metadata["changelog_uri"] = "https://github.com/gemstack-rb/gemstack/blob/main/gems/gemstack-mail/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/gemstack-rb/gemstack/issues"
  spec.metadata["documentation_uri"] = "https://github.com/gemstack-rb/gemstack/tree/main/docs"

  spec.add_dependency "erubi", "~> 1.13" # templates, HTML-escaped by default
  spec.add_dependency "gemstack-core", version
  spec.add_dependency "mail", "~> 2.9"   # message building and SMTP
end
