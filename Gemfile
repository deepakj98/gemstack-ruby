# frozen_string_literal: true

source "https://rubygems.org"

# Every GemStack gem is developed in this monorepo.
path "gems" do
  gem "gemstack"
  gem "gemstack-cache"
  gem "gemstack-cli"
  gem "gemstack-contract"
  gem "gemstack-core"
  gem "gemstack-db"
  gem "gemstack-dev"
  gem "gemstack-http"
  gem "gemstack-jobs"
  gem "gemstack-schema"
end

group :development, :test do
  gem "benchmark" # a bundled (not default) gem since Ruby 4.0
  gem "brotli", "~> 0.8" # optional in apps; tested here
  gem "minitest", "~> 5.25"
  gem "oj", "~> 3.16"
  gem "rack-test", "~> 2.2"
  gem "rake", "~> 13.0"
  gem "redis-client", "~> 0.25" # optional in apps (cache :redis store); tested here
  gem "rubocop", "~> 1.81", require: false
  gem "sidekiq", "~> 8.1" # optional in apps (jobs :sidekiq adapter); tested here
end
