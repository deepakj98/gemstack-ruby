# frozen_string_literal: true

require "erb"
require "fileutils"

module GemStack
  class CLI < Thor
    # Shared machinery for generators: renders a template directory into a
    # destination. Files ending in .tt are ERB templates evaluated against the
    # generator; a leading "dot_" in a file name becomes "." (so dotfiles
    # survive gem packaging). Existing files are never overwritten silently.
    #
    # Applications can override any template by placing a file with the same
    # relative path in lib/templates/gemstack/<generator>/ (ARCHITECTURE §7).
    class Generator
      TEMPLATES = File.expand_path("../../../templates", __dir__)

      attr_reader :created

      def initialize(output: $stdout, force: false)
        @output = output
        @force = force
        @created = []
      end

      def template_root(name) = File.join(TEMPLATES, name)

      # Every template file for a generator, with app overrides applied.
      def template_files(name, override_root: nil)
        files = relative_files(template_root(name)).to_h { |rel| [rel, File.join(template_root(name), rel)] }
        if override_root
          custom = File.join(override_root, "lib/templates/gemstack", name)
          relative_files(custom).each { |rel| files[rel] = File.join(custom, rel) } if File.directory?(custom)
        end
        files
      end

      def render_directory(name, destination, override_root: nil, skip: nil)
        template_files(name, override_root: override_root).sort.each do |rel, source|
          next if skip&.call(rel)

          target = File.join(destination, output_path(rel))
          content = File.binread(source)
          content = render(content, source) if source.end_with?(".tt")
          write(target, content, mode: File.stat(source).mode)
        end
      end

      def render(content, source = "(template)")
        erb = ERB.new(content, trim_mode: "-")
        erb.filename = source
        erb.result(binding)
      end

      def write(path, content, mode: nil)
        if File.exist?(path) && !@force
          if File.binread(path) == content
            status("identical", path)
          else
            status("skip", path, "exists — not overwritten")
          end
          return false
        end
        FileUtils.mkdir_p(File.dirname(path))
        File.binwrite(path, content)
        File.chmod(mode & 0o777, path) if mode
        @created << path
        status("create", path)
        true
      end

      def status(label, path, note = nil)
        shown = path.delete_prefix("#{Dir.pwd}/")
        @output.puts("  #{label.rjust(9)}  #{shown}#{"  (#{note})" if note}")
      end

      private

      def relative_files(root)
        Dir.glob("**/*", File::FNM_DOTMATCH, base: root)
           .reject { |rel| File.directory?(File.join(root, rel)) || File.basename(rel) == ".DS_Store" }
      end

      def output_path(rel)
        rel.delete_suffix(".tt").split("/").map { |part| part.sub(/\Adot_/, ".") }.join("/")
      end
    end
  end
end
