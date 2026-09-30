# frozen_string_literal: true

# Transition shims are released once, at 0.3.0, and depend on any later
# gemstack, so apps that still list them can keep upgrading.
version = "0.3.0"

# gemstack-storage was merged into the gemstack gem in 0.3.0. This is a transition shim
# so existing Gemfiles keep working; it depends on gemstack and loads gemstack/storage.
Gem::Specification.new do |spec|
  spec.name = "gemstack-storage"
  spec.version = version
  spec.summary = "Merged into the gemstack gem — remove gemstack-storage from your Gemfile"
  spec.description = "Since GemStack 0.3.0, gemstack-storage is part of the gemstack gem. This version only depends " \
                     "on gemstack and loads gemstack/storage, so Gemfiles that still list it keep working."
  spec.authors = ["Adware Technologies", "Shoaib Malik"]
  spec.email = ["gemstack26@gmail.com"]
  spec.license = "MIT"
  spec.homepage = "https://github.com/gemstack-rb/gemstack"
  spec.required_ruby_version = ">= 3.3"
  spec.files = Dir["README.md", "LICENSE.txt", "CHANGELOG.md", "lib/**/*.rb"]
  spec.require_paths = ["lib"]
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["source_code_uri"] = "https://github.com/gemstack-rb/gemstack"
  spec.metadata["changelog_uri"] = "https://github.com/gemstack-rb/gemstack/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/gemstack-rb/gemstack/issues"
  spec.metadata["documentation_uri"] = "https://github.com/gemstack-rb/gemstack/tree/main/docs"
  spec.post_install_message = "gemstack-storage is now part of the gemstack gem. Remove `gem " \
                              "\"gemstack-storage\"` from your Gemfile and make sure `config/app.rb` has " \
                              "`require \"gemstack/storage\"` (apps created with 0.3.0 do)."

  spec.add_dependency "gemstack", ">= #{version}", "< 1.0"
end
