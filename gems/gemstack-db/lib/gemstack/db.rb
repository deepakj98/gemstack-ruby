# frozen_string_literal: true

require "sequel"
require "json"
require "gemstack/core"
require "gemstack/schema"

require_relative "db/json_compat"

module GemStack
  # PostgreSQL through Sequel (DECISIONS D-018). Optional: add
  # `gem "gemstack-db"` to the Gemfile (new apps include it by default).
  #
  #   GemStack.db[:products].where(active: true).count     # the Sequel::Database
  #   GemStack.transaction { order.save; payment.save }
  module DB
    class Config < Settings
      # Test uses TEST_DATABASE_URL so a DATABASE_URL meant for development
      # (e.g. from .env) can never be used by the test suite.
      setting :url, default: lambda {
        env = GemStack.env
        name = "#{GemStack.config.name.tr("-", "_")}_#{env}"
        (env.test? ? ENV.fetch("TEST_DATABASE_URL", nil) : ENV.fetch("DATABASE_URL", nil)) || "postgres:///#{name}"
      }
      # One connection per server thread by default.
      setting :pool_size, default: lambda {
        Integer(ENV.fetch("GEMSTACK_DB_POOL") { ENV.fetch("GEMSTACK_MAX_THREADS", 5) })
      }
      setting :pool_timeout, default: 5
      setting :migrations_path, default: "db/migrations"
      setting :seeds_path, default: "db/seeds.rb"
      setting :log_queries, default: -> { GemStack.env.development? }
      # Queries slower than this are logged at WARN in every environment.
      setting :slow_query_ms, default: 500
      # Server-side statement timeout in ms (nil = PostgreSQL default).
      setting :statement_timeout, default: nil
      setting :extensions, default: %i[pg_json pg_array]
      # Extra options passed to Sequel.connect.
      setting :options, default: {}
    end

    class RecordNotFound < NotFound; end

    # Adapts Sequel's logging to the GemStack logger: SQL at DEBUG only when
    # config.db.log_queries is on, slow queries at WARN, and failures of the
    # existence probes Sequel runs on purpose (table_exists?, model setup
    # before a migration) are not reported as errors.
    class QueryLogger
      PROBE = /: SELECT (?:NULL AS "nil" FROM \S+ LIMIT 1|\* FROM \S+ LIMIT 0)\z/

      def initialize(logger, queries:)
        @logger = logger
        @queries = queries
      end

      def debug(message) = (@logger.debug(message) if @queries)
      def info(message) = @logger.info(message)
      def warn(message) = @logger.warn(message)
      def error(message) = (@logger.error(message) unless PROBE.match?(message.to_s))
    end

    @mutex = Mutex.new

    class << self
      def config = GemStack.config.db

      def connection
        @connection || @mutex.synchronize { @connection ||= connect }
      end

      def connected? = !@connection.nil?

      # Builds the Sequel::Database. Connections are opened lazily, so an
      # unavailable database doesn't prevent the application from booting.
      def connect(url = config.url)
        options = { max_connections: config.pool_size, pool_timeout: config.pool_timeout, test: false,
                    keep_reference: false }
        timeout = config.statement_timeout
        options[:after_connect] = ->(conn) { conn.exec("SET statement_timeout = #{Integer(timeout)}") } if timeout
        db = Sequel.connect(url, **options, **config.options)
        db.extension(*config.extensions) unless config.extensions.empty?
        db.log_warn_duration = config.slow_query_ms / 1000.0 if config.slow_query_ms
        db.loggers << QueryLogger.new(GemStack.logger, queries: config.log_queries)
        db.sql_log_level = :debug
        Sequel::Model.db = db
        db
      end

      # Closes pooled connections (e.g. before Puma forks workers). The
      # Database object stays in place and reconnects lazily: models hold a
      # reference to it, so replacing it would split them from GemStack.db.
      def disconnect
        @connection&.disconnect
      end

      def transaction(**, &) = connection.transaction(**, &)
    end
  end

  # A model base class bound to an explicit table, like Sequel::Model(:table):
  #   class Item < GemStack::Model(:inventory_items)
  def self.Model(source) = Model.Model(source) # rubocop:disable Naming/MethodName

  class << self
    def db = DB.connection
    def transaction(**, &) = DB.transaction(**, &)
  end
end

require_relative "db/model"
require_relative "db/errors"
require_relative "db/migrator"
require_relative "db/tasks"

GemStack::Config.namespace(:db, GemStack::DB::Config)

GemStack::Plugins.register(:db) do |app|
  GemStack::DB.connection
  app.on_shutdown { GemStack::DB.disconnect } if app.respond_to?(:on_shutdown)

  # A friendly nudge in development; never blocks boot.
  if GemStack.env.development?
    begin
      pending = GemStack::DB::Migrator.new.pending
      unless pending.empty?
        GemStack.logger.warn("#{pending.size} pending migration(s) — run `gemstack db:migrate`",
                             first: pending.first.file)
      end
    rescue Sequel::Error
      nil # database not reachable yet; requests will report it
    end
  end
end
