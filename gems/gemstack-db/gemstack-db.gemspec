# frozen_string_literal: true

# All GemStack gems share one version; change it with `rake version:set[x.y.z]`.
version = "0.2.2"

Gem::Specification.new do |spec|
  spec.name = "gemstack-db"
  spec.version = version
  spec.summary = "GemStack database: Sequel models and migrations for SQLite, PostgreSQL and MySQL"
  spec.authors = ["Adware Technologies", "Shoaib Malik"]
  spec.email = ["gemstack26@gmail.com"]
  spec.license = "MIT"
  spec.homepage = "https://github.com/gemstack-rb/gemstack"
  spec.required_ruby_version = ">= 4.0"
  spec.files = Dir["README.md", "LICENSE.txt", "CHANGELOG.md", "lib/**/*.rb"]
  spec.require_paths = ["lib"]
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["source_code_uri"] = "https://github.com/gemstack-rb/gemstack/tree/main/gems/gemstack-db"
  spec.metadata["changelog_uri"] = "https://github.com/gemstack-rb/gemstack/blob/main/gems/gemstack-db/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/gemstack-rb/gemstack/issues"
  spec.metadata["documentation_uri"] = "https://github.com/gemstack-rb/gemstack/tree/main/docs"

  spec.add_dependency "gemstack-core", version
  spec.add_dependency "gemstack-schema", version
  spec.add_dependency "sequel", "~> 5.80"
  # The driver is the app's choice (like Rails): gem "pg", "mysql2", "trilogy" or "sqlite3".
end
