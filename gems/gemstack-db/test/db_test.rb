# frozen_string_literal: true

require "test_helper"

class DBConfigTest < Minitest::Test
  def test_url_defaults
    config = GemStack::DB::Config.new
    previous = GemStack.config.name
    GemStack.config.name = "my-shop"

    assert_equal "postgres:///my_shop_test", config.url
  ensure
    GemStack.config.name = previous
  end

  def test_test_env_ignores_development_database_url
    ENV["DATABASE_URL"] = "postgres:///dev_db"
    ENV["TEST_DATABASE_URL"] = "postgres:///test_db"

    assert_equal "postgres:///test_db", GemStack::DB::Config.new.url
  ensure
    ENV.delete("DATABASE_URL")
    ENV.delete("TEST_DATABASE_URL")
  end

  def test_pool_follows_server_threads
    ENV["GEMSTACK_MAX_THREADS"] = "9"

    assert_equal 9, GemStack::DB::Config.new.pool_size
  ensure
    ENV.delete("GEMSTACK_MAX_THREADS")
  end

  def test_tasks_url_helpers
    url = "postgres://u:p@db.local:5433/shop_dev?sslmode=require"

    assert_equal "shop_dev", GemStack::DB::Tasks.database_name(url)
    assert_equal "postgres://u:p@db.local:5433/postgres?sslmode=require", GemStack::DB::Tasks.maintenance_url(url)
  end
end

class DBTasksTest < Minitest::Test
  include DBTest

  def test_create_exists_drop
    url = DBTest::URL.sub(%r{/[^/?]+(\?|\z)}, "/gemstack_tasks_probe\\1")
    GemStack::DB::Tasks.drop(url)

    assert_equal :created, GemStack::DB::Tasks.create(url)
    assert_equal :exists, GemStack::DB::Tasks.create(url)
    assert GemStack::DB::Tasks.exists?(url)
    assert_equal :dropped, GemStack::DB::Tasks.drop(url)
    refute GemStack::DB::Tasks.exists?(url)
  end

  def test_drop_refused_in_production
    GemStack.env = "production"

    assert_raises(GemStack::Error) { GemStack::DB::Tasks.drop }
  ensure
    GemStack.env = "test"
  end
end

class MigratorTest < Minitest::Test
  include DBTest

  def setup
    super
    @dir = Dir.mktmpdir
    File.write("#{@dir}/20260101000000_create_gadgets.rb", <<~RUBY)
      Sequel.migration do
        change do
          create_table(:migrator_gadgets) { primary_key :id }
        end
      end
    RUBY
    File.write("#{@dir}/20260102000000_add_name.rb", <<~RUBY)
      Sequel.migration do
        change do
          add_column :migrator_gadgets, :name, String
        end
      end
    RUBY
    @migrator = GemStack::DB::Migrator.new(db, @dir)
    @migrator.migrate(target: 0)
  end

  def teardown
    @migrator&.migrate(target: 0)
    FileUtils.rm_rf(@dir) if @dir
  end

  def test_migrate_status_rollback
    assert_equal 2, @migrator.pending.size
    applied = @migrator.migrate

    assert_equal %w[20260101000000_create_gadgets.rb 20260102000000_add_name.rb], applied.sort
    assert_includes db[:migrator_gadgets].columns, :name
    refute_predicate @migrator, :pending?
    assert_equal ["create_gadgets", true], [@migrator.status.first.name, @migrator.status.first.applied]

    assert_equal ["20260102000000_add_name.rb"], @migrator.rollback
    refute_includes db.schema(:migrator_gadgets, reload: true).map(&:first), :name
    @migrator.rollback(steps: 5)

    refute db.table_exists?(:migrator_gadgets)
  end

  def test_migrate_is_idempotent
    @migrator.migrate

    assert_empty @migrator.migrate
  end
end

class QueryLoggerTest < Minitest::Test
  def logger(queries)
    @io = StringIO.new
    GemStack::DB::QueryLogger.new(GemStack::Logger.new(@io, level: :debug, color: false), queries: queries)
  end

  def test_sql_only_when_enabled
    logger(false).debug("(0.1ms) SELECT 1")

    assert_empty @io.string
    logger(true).debug("(0.1ms) SELECT 1")

    assert_includes @io.string, "SELECT 1"
  end

  def test_probe_failures_are_not_errors
    log = logger(false)
    log.error(%(PG::UndefinedTable: ERROR:  relation "x" does not exist: SELECT NULL AS "nil" FROM "x" LIMIT 1))
    log.error(%(PG::UndefinedTable: ERROR:  relation "x" does not exist: SELECT * FROM "x" LIMIT 0))

    assert_empty @io.string
    log.error("PG::SyntaxError: boom: SELECT oops")

    assert_includes @io.string, "boom"
  end

  def test_slow_queries_always_warn
    logger(false).warn("(812ms) SELECT slow")

    assert_includes @io.string, "WARN"
  end
end

class LoadWithoutDatabaseTest < Minitest::Test
  # Requiring gemstack-db must never need a database connection.
  def test_requires_without_a_connection
    lib = %w[gemstack-core gemstack-schema gemstack-db].map { |g| "-I#{File.expand_path("../../#{g}/lib", __dir__)}" }
    ok = system(RbConfig.ruby, *lib, "-e", 'require "gemstack/db"; exit(GemStack::Model.name == "GemStack::Model" ? 0 : 1)')

    assert ok, "gemstack/db should load without a database"
  end
end
