# frozen_string_literal: true

require "uri"

module GemStack
  module DB
    # Database lifecycle used by `gemstack db:*`.
    module Tasks
      module_function

      def database_name(url = DB.config.url)
        URI.parse(url).path.delete_prefix("/").then { |n| URI.decode_www_form_component(n) }
      end

      # The same server with the "postgres" maintenance database.
      def maintenance_url(url = DB.config.url)
        uri = URI.parse(url)
        uri.path = "/postgres"
        uri.to_s
      end

      def exists?(url = DB.config.url)
        with_maintenance(url) { |db| db[:pg_database].where(datname: database_name(url)).any? }
      end

      # Returns :created or :exists.
      def create(url = DB.config.url)
        return :exists if exists?(url)

        with_maintenance(url) { |db| db.run("CREATE DATABASE #{db.literal(Sequel.identifier(database_name(url)))}") }
        :created
      end

      # Refuses outside development/test unless GEMSTACK_ALLOW_DB_DROP=1.
      def drop(url = DB.config.url)
        unless GemStack.env.local? || ENV["GEMSTACK_ALLOW_DB_DROP"] == "1"
          raise Error, "refusing to drop the #{GemStack.env} database; set GEMSTACK_ALLOW_DB_DROP=1 to confirm"
        end
        return :missing unless exists?(url)

        DB.disconnect
        with_maintenance(url) do |db|
          db.run("DROP DATABASE #{db.literal(Sequel.identifier(database_name(url)))} WITH (FORCE)")
        end
        :dropped
      end

      def seed(path = GemStack.root.join(DB.config.seeds_path))
        return false unless File.file?(path)

        load path.to_s
        true
      end

      def with_maintenance(url)
        db = Sequel.connect(maintenance_url(url), max_connections: 1, test: true, keep_reference: false)
        yield db
      ensure
        db&.disconnect
      end
    end
  end
end
