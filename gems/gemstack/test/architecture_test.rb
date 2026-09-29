# frozen_string_literal: true

require "test_helper"
require "open3"
require "rbconfig"

# Enforces the module boundaries described in ARCHITECTURE.md §2.
class ArchitectureTest < Minitest::Test
  GEMS_DIR = File.expand_path("../..", __dir__)
  # Dependencies may only point to gems earlier in this list.
  ORDER = %w[gemstack-core gemstack-cache gemstack-schema gemstack-http gemstack-db gemstack-jobs gemstack-realtime
             gemstack-mail gemstack-storage gemstack-auth gemstack-contract gemstack-dev gemstack-cli gemstack].freeze

  def specs
    @specs ||= ORDER.to_h do |name|
      [name, Gem::Specification.load(File.join(GEMS_DIR, name, "#{name}.gemspec"))]
    end
  end

  def gemstack_deps(name)
    specs.fetch(name).runtime_dependencies.map(&:name).grep(/\Agemstack/)
  end

  def test_one_version_and_publishable_metadata
    ORDER.each do |name|
      spec = specs.fetch(name)

      assert_equal GemStack::VERSION, spec.version.to_s, "#{name}: rake version:set keeps every gem on one version"
      assert_equal ["Shoaib Malik"], spec.authors
      assert_equal "MIT", spec.license
      assert_equal "true", spec.metadata["rubygems_mfa_required"]
      %w[source_code_uri changelog_uri bug_tracker_uri documentation_uri].each do |key|
        assert spec.metadata[key]&.start_with?("https://github.com/gemstack-rb/gemstack"), "#{name}: #{key}"
      end
      %w[README.md LICENSE.txt CHANGELOG.md].each do |file|
        assert File.file?(File.join(GEMS_DIR, name, file)), "#{name} is missing #{file}"
      end
      gemstack_deps(name).each do |dep|
        requirement = spec.runtime_dependencies.find { |d| d.name == dep }.requirement.to_s
        assert_equal "= #{GemStack::VERSION}", requirement, "#{name} pins #{dep} to the same version"
      end
    end
  end

  def test_core_has_no_runtime_dependencies
    assert_empty specs.fetch("gemstack-core").runtime_dependencies
  end

  def test_core_source_never_references_other_modules
    offenders = Dir[File.join(GEMS_DIR, "gemstack-core/lib/**/*.rb")].select do |file|
      code = File.readlines(file).grep_v(/\A\s*#/).join
      code.match?(%r{require\s+["']gemstack/(?!core|version|settings)|GemStack::(HTTP|Dev|CLI)\b})
    end

    assert_empty offenders
  end

  def test_nothing_depends_on_the_umbrella_and_there_are_no_cycles
    ORDER.each do |name|
      refute_includes gemstack_deps(name), "gemstack", "#{name} must not depend on the umbrella gem"
      # Dependencies only point "down" the ORDER list, which rules out cycles.
      gemstack_deps(name).each do |dep|
        assert_operator ORDER.index(dep), :<, ORDER.index(name), "#{name} → #{dep} points up the graph"
      end
    end
  end

  def test_database_is_optional
    refute_includes gemstack_deps("gemstack"), "gemstack-db"
    refute_includes gemstack_deps("gemstack-db"), "gemstack-http", "the DB layer must not depend on HTTP"
  end

  def test_core_loads_alone
    lib = File.join(GEMS_DIR, "gemstack-core/lib")
    script = 'require "gemstack/core"; print [defined?(GemStack::HTTP), defined?(Rack), defined?(Thor)].compact.size'
    out, status = Open3.capture2e(RbConfig.ruby, "--disable-gems", "-I", lib, "-e", script)

    assert_predicate status, :success?, out
    assert_equal "0", out
  end

  def test_dev_tooling_is_not_loaded_by_default
    %w[Gateway Supervisor ManagedProcess].each do |name|
      assert_equal "gemstack/dev/#{Inflector.underscore(name)}", GemStack::Dev.autoload?(name.to_sym)
    end
  end

  Inflector = GemStack::Inflector
end
