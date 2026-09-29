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
    INSTALL_ORDER.each do |name|
      file = "#{name}-#{GemStack::VERSION}.gem"
      sh "gem install pkg/#{file} --no-document"
      # Reinstalling the same version keeps RubyGems' cached .gem, which
      # `bundle cache` (vendor/cache for Docker builds) would then copy.
      cp "pkg/#{file}", File.join(Gem.dir, "cache", file)
    end
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

# The suites that touch the database, run once per adapter:
# SQLite always; PostgreSQL with GEMSTACK_TEST_DATABASE_URL; MySQL (mysql2 and
# trilogy) with GEMSTACK_TEST_MYSQL_URL=mysql2://user:pass@127.0.0.1:3306/gemstack_test.
DATABASE_SUITES = %w[test:gemstack-db test:gemstack-jobs test:gemstack-auth].freeze

desc "Run the database-backed suites on SQLite, PostgreSQL and MySQL (where configured)"
task "test:databases" do
  require "tmpdir"
  Dir.mktmpdir("gemstack-sqlite") do |dir|
    urls = { "sqlite3" => "sqlite3://#{dir}/gemstack_test.sqlite3" }
    if ENV["GEMSTACK_TEST_DATABASE_URL"].to_s.start_with?("postgres")
      urls["postgresql"] =
        ENV.fetch("GEMSTACK_TEST_DATABASE_URL", nil)
    end
    if (mysql = ENV.fetch("GEMSTACK_TEST_MYSQL_URL", nil)).to_s != ""
      urls["mysql2"] = mysql.sub(/\A\w+:/, "mysql2:")
      urls["trilogy"] = mysql.sub(/\A\w+:/, "trilogy:")
    end
    urls.each do |adapter, url|
      puts "\n== #{adapter}"
      sh({ "GEMSTACK_TEST_DATABASE_URL" => url }, "bundle", "exec", "rake", *DATABASE_SUITES)
    end
    skipped = %w[postgresql mysql2] - urls.keys
    if skipped.any?
      puts "\n(not run on #{skipped.join(", ")}: set GEMSTACK_TEST_DATABASE_URL / GEMSTACK_TEST_MYSQL_URL)"
    end
  end
end

task default: %i[test test:databases lint]

desc "Set the version of every GemStack gem: rake version:set[0.2.0]"
task "version:set", [:version] do |_, args|
  version = args[:version].to_s
  abort "usage: rake version:set[x.y.z]" unless version.match?(/\A\d+\.\d+\.\d+(\.[0-9A-Za-z.]+)?\z/)

  files = Dir["gems/*/*.gemspec"] + ["gems/gemstack-core/lib/gemstack/version.rb"]
  files.each do |file|
    content = File.read(file)
    updated = content.sub(/^(\s*(?:VERSION|version) = )"[^"]+"/, "\\1\"#{version}\"")
    File.write(file, updated) unless updated == content
  end
  puts "Set #{files.size} files to #{version}. Add a CHANGELOG.md entry, then run `bundle install` and the tests."
end

namespace :gems do
  desc "Build every gem and install them into a throwaway GEM_HOME, then run `gemstack new` from them"
  task check: :build do
    require "tmpdir"
    Dir.mktmpdir("gemstack-gems") do |home|
      env = { "GEM_HOME" => home, "GEM_PATH" => home, "BUNDLE_GEMFILE" => nil, "RUBYOPT" => nil }
      gems = INSTALL_ORDER.map { |name| "pkg/#{name}-#{GemStack::VERSION}.gem" }
      Bundler.with_unbundled_env do
        sh env, "gem", "install", "--no-document", "--quiet", *gems
        sh env, File.join(home, "bin", "gemstack"), "version"
        sh env, File.join(home, "bin", "gemstack"), "new", File.join(home, "check_app"), "--skip-install", "--skip-git"
      end
      puts "All #{gems.size} gems build, install and generate an app."
    end
  end
end
