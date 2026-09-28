# frozen_string_literal: true

module GemStack
  class CLI < Thor
    # `gemstack add FEATURE` — opt-in modules, so apps that don't use them
    # pay nothing. Currently: realtime.
    class AddGenerator < Generator
      FEATURES = %w[realtime].freeze

      def initialize(feature, root:, output: $stdout, install: true)
        super(output: output)
        unless FEATURES.include?(feature)
          raise Thor::Error,
                "Unknown feature #{feature.inspect}. Available: #{FEATURES.join(", ")}"
        end

        @feature = feature
        @root = root
        @install = install
      end

      def run
        public_send(:"add_#{@feature}")
        self
      end

      def add_realtime
        add_gem("gemstack-realtime")
        template_files("realtime", override_root: @root).each do |rel, source|
          next if rel.start_with?("frontend/") && !File.directory?(File.join(@root, "frontend"))

          write(File.join(@root, rel), File.read(source))
        end
        add_test_support('require "gemstack/realtime/testing"', "GemStack::Realtime::Testing")
        bundle_install
      end

      private

      # Adds the gem inside the GemStack `path` block (checkout apps) or as a
      # versioned dependency next to gem "gemstack".
      def add_gem(name)
        path = File.join(@root, "Gemfile")
        content = File.read(path)
        return status("identical", path, name) if content.match?(/^\s*gem "#{name}"/)

        updated = content.match?(/^path ".*" do\n/) ? add_to_path_block(content, name) : add_versioned(content, name)
        if updated == content
          raise Thor::Error,
                "couldn't find where to add #{name} in the Gemfile; add `gem \"#{name}\"` yourself"
        end

        File.write(path, updated)
        status("gemfile", path, name)
      end

      # Keeps the block's gems in alphabetical order (Bundler/OrderedGems).
      def add_to_path_block(content, name)
        content.sub(/^(path ".*" do\n)((?:  gem .*\n)*)/) do
          opening = ::Regexp.last_match(1)
          lines = ::Regexp.last_match(2) # before sort_by's regexes reset last_match
          gems = (lines.lines + ["  gem \"#{name}\"\n"]).sort_by { |line| line[/"([^"]+)"/, 1] }
          opening + gems.join
        end
      end

      def add_versioned(content, name)
        content.sub(/^gem "gemstack",.*\n/) { |line| "#{line}gem \"#{name}\", \"~> #{GemStack::VERSION}\"\n" }
      end

      def add_test_support(require_line, mixin)
        path = File.join(@root, "test/test_helper.rb")
        return unless File.file?(path)

        content = File.read(path)
        return status("identical", path) if content.include?(mixin)

        content = content.sub(%(require "gemstack/testing"\n)) { |line| "#{line}#{require_line}\n" }
        content = "#{content.rstrip}\nGemStack::TestCase.include #{mixin}\n"
        File.write(path, content)
        status("update", path, mixin)
      end

      def bundle_install
        return unless @install

        status("run", "bundle install")
        install = -> { system("bundle", "install", "--quiet", chdir: @root) }
        ok = defined?(Bundler) ? Bundler.with_unbundled_env(&install) : install.call
        status("warning", "bundle install failed — run it yourself") unless ok
      end
    end
  end
end
