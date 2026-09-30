# frozen_string_literal: true

require "test_helper"
require "open3"
require "rbconfig"

# gems/gemstack-cli/exe/gemstack: the installed `gemstack` command.
class LauncherTest < Minitest::Test
  REPO = File.expand_path("../../../..", __dir__)
  EXE = File.join(REPO, "gems/gemstack-cli/exe/gemstack")

  # Runs the launcher without RubyGems, so only the -I paths can be required.
  def launch(*load_paths)
    args = load_paths.flat_map { |path| ["-I", File.join(REPO, path)] }
    clean = { "RUBYOPT" => nil, "RUBYLIB" => nil, "BUNDLE_GEMFILE" => nil, "BUNDLE_BIN_PATH" => nil }
    Open3.capture2e(clean, RbConfig.ruby, "--disable-gems", *args, EXE, "version")
  end

  def test_says_how_to_install_gemstack_when_it_is_missing
    out, status = launch

    refute_predicate status, :success?
    assert_includes out, "the gemstack gem is missing — install it with: gem install gemstack"
  end

  def test_a_missing_dependency_keeps_its_own_error
    out, status = launch("gems/gemstack/lib")

    refute_predicate status, :success?
    assert_includes out, "cannot load such file -- thor"
    refute_includes out, "the gemstack gem is missing"
  end
end
