# frozen_string_literal: true

require "rake/testtask"

GEMS = %w[gemstack-core gemstack-cache gemstack-schema gemstack-http gemstack-db gemstack-jobs gemstack-realtime
          gemstack-mail gemstack-storage gemstack-auth gemstack-contract gemstack-dev gemstack-cli gemstack].freeze

namespace :test do
  GEMS.each do |name|
    Rake::TestTask.new(name) do |t|
      t.libs = GEMS.map { |g| "gems/#{g}/lib" } + ["gems/#{name}/test"]
      t.test_files = FileList["gems/#{name}/test/**/*_test.rb"]
      t.warning = false
    end
  end
end

# Dependency order: each gem only depends on gems before it (ARCHITECTURE §2).
INSTALL_ORDER = %w[
  gemstack-core gemstack-cache gemstack-schema gemstack-http gemstack-db gemstack-jobs gemstack-realtime
  gemstack-mail gemstack-storage gemstack-auth gemstack-contract gemstack-dev gemstack-cli gemstack
].freeze

namespace :gems do
  require_relative "gems/gemstack-core/lib/gemstack/version"

  desc "Build every gem into pkg/"
  task :build do
    mkdir_p "pkg"
    INSTALL_ORDER.each do |name|
      Dir.chdir("gems/#{name}") { sh "gem build #{name}.gemspec --output ../../pkg/#{name}-#{GemStack::VERSION}.gem" }
    end
  end

  desc "Build and install every gem for the current Ruby (like `gem install gemstack`)"
  task install: :build do
    INSTALL_ORDER.each { |name| sh "gem install pkg/#{name}-#{GemStack::VERSION}.gem --no-document" }
    sh "asdf reshim ruby" if system("which asdf > /dev/null 2>&1")
  end

  desc "Uninstall every GemStack gem from the current Ruby"
  task :uninstall do
    INSTALL_ORDER.reverse_each { |name| sh "gem uninstall #{name} --all --executables --ignore-dependencies --force" }
  end
end

desc "Run the test suite of every gem"
task test: GEMS.map { |name| "test:#{name}" }

desc "Run RuboCop"
task :lint do
  sh "bundle exec rubocop"
end

desc "Run benchmarks"
task :bench do
  Dir["benchmarks/*_bench.rb"].each { |file| ruby file }
end

task default: %i[test lint]
