# frozen_string_literal: true

require "rake/testtask"

# The published gems, in dependency order: gemstack-cli (only the executable)
# first, then gemstack (the framework), then the two optional modules.
GEMS = %w[gemstack-cli gemstack gemstack-auth gemstack-realtime].freeze
# The names merged into gemstack in 0.3.0: released once as transition shims
# (each depends on gemstack >= 0.3.0 and loads its module), never again.
SHIMS = %w[gemstack-core gemstack-cache gemstack-schema gemstack-http gemstack-db gemstack-jobs gemstack-mail
           gemstack-storage gemstack-contract gemstack-dev].freeze
LIBS = (GEMS - ["gemstack-cli"]).map { |gem| "gems/#{gem}/lib" }.freeze

# One test task per module (rake test:http, test:db, …) and per extra gem.
SUITES = (Dir["gems/gemstack/test/*/"].map { |dir| [File.basename(dir), dir] } +
          [["auth", "gems/gemstack-auth/test/"], ["realtime", "gems/gemstack-realtime/test/"]]).sort.freeze

namespace :test do
  SUITES.each do |name, dir|
    Rake::TestTask.new(name) do |t|
      t.libs = LIBS + [dir.chomp("/")]
      t.test_files = FileList["#{dir}**/*_test.rb"]
      t.warning = false
    end
  end
end

desc "Run every test suite"
task test: SUITES.map { |name, _| "test:#{name}" }

def gem_version(name) = Gem::Specification.load(File.expand_path("gems/#{name}/#{name}.gemspec", __dir__)).version.to_s

namespace :gems do
  require_relative "gems/gemstack/lib/gemstack/version"

  desc "Build every gem (and the shims) into pkg/"
  task :build do
    mkdir_p "pkg"
    (GEMS + SHIMS).each do |name|
      file = "#{name}-#{gem_version(name)}.gem"
      Dir.chdir("gems/#{name}") { sh "gem build #{name}.gemspec --output ../../pkg/#{file}" }
    end
  end

  desc "Build and install the gems for the current Ruby (like `gem install gemstack`)"
  task install: :build do
    GEMS.each do |name|
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
    (SHIMS + GEMS.reverse).each { |name| sh "gem uninstall #{name} --all --executables --ignore-dependencies --force" }
  end

  desc "Build the gems, install them into a throwaway GEM_HOME, then run `gemstack new` from them"
  task check: :build do
    require "tmpdir"
    Dir.mktmpdir("gemstack-gems") do |home|
      env = { "GEM_HOME" => home, "GEM_PATH" => home, "BUNDLE_GEMFILE" => nil, "RUBYOPT" => nil }
      files = (GEMS + SHIMS).map { |name| "pkg/#{name}-#{gem_version(name)}.gem" }
      Bundler.with_unbundled_env do
        sh env, "gem", "install", "--no-document", "--quiet", *files
        sh env, File.join(home, "bin", "gemstack"), "version"
        sh env, File.join(home, "bin", "gemstack"), "new", File.join(home, "check_app"), "--skip-install", "--skip-git"
      end
      puts "All #{files.size} gems build, install and generate an app."
    end
  end
end

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
DATABASE_SUITES = %w[test:db test:jobs test:auth].freeze

desc "Run the database-backed suites on SQLite, PostgreSQL and MySQL (where configured)"
task "test:databases" do
  require "tmpdir"
  Dir.mktmpdir("gemstack-sqlite") do |dir|
    urls = { "sqlite3" => "sqlite3://#{dir}/gemstack_test.sqlite3" }
    if ENV["GEMSTACK_TEST_DATABASE_URL"].to_s.start_with?("postgres")
      urls["postgresql"] =
        ENV.fetch("GEMSTACK_TEST_DATABASE_URL")
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

desc "Set the version of gemstack, gemstack-cli, gemstack-auth and gemstack-realtime: rake version:set[0.3.1]"
task "version:set", [:version] do |_, args|
  version = args[:version].to_s
  abort "usage: rake version:set[x.y.z]" unless version.match?(/\A\d+\.\d+\.\d+(\.[0-9A-Za-z.]+)?\z/)

  files = GEMS.map { |name| "gems/#{name}/#{name}.gemspec" } + ["gems/gemstack/lib/gemstack/version.rb"]
  files.each do |file|
    content = File.read(file)
    updated = content.sub(/^(\s*(?:VERSION|version) = )"[^"]+"/, "\\1\"#{version}\"")
    File.write(file, updated) unless updated == content
  end
  puts "Set #{files.size} files to #{version}. Add a CHANGELOG.md entry, then run `bundle install` and the tests."
end
