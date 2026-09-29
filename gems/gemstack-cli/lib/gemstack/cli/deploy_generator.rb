# frozen_string_literal: true

module GemStack
  class CLI < Thor
    # `gemstack generate deploy` — Dockerfile (api + web targets), compose.yaml
    # (Postgres, migrations, API, jobs, Next.js, Caddy), Caddyfile, Procfile and
    # .dockerignore (DECISIONS D-058). Nothing is deployed anywhere.
    class DeployGenerator < Generator
      def initialize(root:, output: $stdout, force: false)
        super(output: output, force: force)
        @root = root
      end

      def app_name = File.basename(@root).downcase.gsub(/[^a-z0-9_-]/, "-")
      def frontend? = File.file?(File.join(@root, "frontend/package.json"))

      # A worker process is needed for background jobs (and auth's emails).
      def jobs?
        return true if gemfile.match?(/^\s*gem "gemstack-auth"/)

        gemfile.match?(/^\s*gem "gemstack-jobs"/) &&
          %w[app/jobs/*.rb app/mailers/*.rb].any? { |glob| !Dir.glob(File.join(@root, glob)).empty? }
      end

      def mail? = gemfile.match?(/^\s*gem "gemstack-(mail|auth)"/)

      def ruby_version
        pinned = File.file?(File.join(@root, ".ruby-version")) && File.read(File.join(@root, ".ruby-version")).strip
        pinned && !pinned.empty? ? pinned.delete_prefix("ruby-") : RUBY_VERSION
      end

      def node_version
        tools = File.join(@root, ".tool-versions")
        pinned = File.file?(tools) && File.read(tools)[/^nodejs\s+(\d+)/, 1]
        pinned || "22"
      end

      def run
        template_files("deploy", override_root: @root).sort.each do |rel, source|
          content = File.read(source)
          content = render(content, source) if rel.end_with?(".tt")
          write(File.join(@root, output_path(rel.delete_suffix(".tt"))), content)
        end
        keep = File.join(@root, "vendor/.keep")
        write(keep, "") unless File.exist?(keep) # the Dockerfile copies vendor/ (e.g. vendor/cache)
        warn_about_local_gems
        self
      end

      private

      def gemfile = @gemfile ||= File.read(File.join(@root, "Gemfile"))

      # Apps generated from a GemStack checkout point at it with an absolute
      # path, which doesn't exist inside the image.
      def warn_about_local_gems
        return unless gemfile.match?(/^path "/)

        status("warning", "Gemfile", "GemStack comes from a local path the image can't see — " \
                                     "run `bundle cache --all` (vendor/cache) or use released gems")
      end
    end
  end
end
