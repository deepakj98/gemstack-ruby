# frozen_string_literal: true

module GemStack
  module Jobs
    # The migration new apps get (and `gemstack jobs:install` writes). Kept
    # as source text so the app owns a plain, readable migration while tests
    # and the generator share one definition.
    module Migration
      SOURCE = <<~RUBY
        # frozen_string_literal: true

        # The GemStack job queue (docs/background-jobs.md). Workers claim rows with
        # FOR UPDATE SKIP LOCKED; finished jobs are deleted, exhausted ones keep failed_at.
        Sequel.migration do
          change do
            create_table(:gemstack_jobs) do
              primary_key :id, type: :Bignum
              String :queue, null: false, default: "default"
              Integer :priority, null: false, default: 100
              String :job_class, null: false
              column :args, :jsonb, null: false, default: Sequel.lit("'[]'::jsonb")
              column :run_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
              Integer :attempts, null: false, default: 0
              String :last_error, text: true
              column :locked_at, :timestamptz
              String :locked_by
              column :failed_at, :timestamptz
              column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

              # The fetch query: ready jobs by queue, in priority/run_at order.
              index %i[queue priority run_at id], name: :gemstack_jobs_ready,
                                                  where: Sequel.lit("failed_at IS NULL AND locked_at IS NULL")
              index :locked_at, name: :gemstack_jobs_locked, where: Sequel.lit("locked_at IS NOT NULL")
              index :failed_at, name: :gemstack_jobs_failed, where: Sequel.lit("failed_at IS NOT NULL")
            end
          end
        end
      RUBY

      def self.apply(db, direction = :up)
        Sequel.extension :migration
        eval(SOURCE, TOPLEVEL_BINDING, "gemstack_jobs_migration.rb").apply(db, direction) # rubocop:disable Security/Eval
      end
    end

    module Adapters
      # The default adapter: jobs are rows in PostgreSQL (DECISIONS D-040).
      #
      # - Enqueueing is an INSERT on the current connection, so inside
      #   GemStack.transaction a job exists only if the transaction commits.
      # - NOTIFY (also transactional) wakes idle workers immediately; polling
      #   every config.jobs.poll_interval is the safety net.
      # - Workers claim one job at a time with FOR UPDATE SKIP LOCKED, so
      #   workers never block each other or run the same job twice at once.
      class Postgres
        CHANNEL = "gemstack_jobs"

        def initialize(db: nil, table: Jobs.config.table)
          @db = db
          @table = table
        end

        def db
          @db || begin
            require "gemstack/db"
            GemStack::DB.connection
          end
        end

        def dataset = db[@table]

        def enqueue(payload)
          id = dataset.insert(
            job_class: payload["job_class"], queue: payload["queue"], priority: payload["priority"],
            args: Sequel.pg_jsonb_wrap(payload["args"]), run_at: payload["run_at"] || Sequel::CURRENT_TIMESTAMP
          )
          db.notify(CHANNEL, payload: payload["queue"])
          id
        end

        # Claims the next ready job for these queues ("*" = all). Returns a
        # payload Hash or nil.
        def claim(queues, worker)
          ready = dataset.where(failed_at: nil, locked_at: nil).where { run_at <= Sequel::CURRENT_TIMESTAMP }
          ready = ready.where(queue: queues) unless queues.include?("*")
          next_id = ready.order(:priority, :run_at, :id).limit(1).for_update.skip_locked.select(:id)
          row = dataset.where(id: next_id).returning(*returned_columns)
                       .update(locked_at: Sequel::CURRENT_TIMESTAMP, locked_by: worker).first
          row && payload_for(row)
        end

        def complete(id) = dataset.where(id: id).delete

        def reschedule(id, run_at:, attempts:, error:)
          dataset.where(id: id).update(locked_at: nil, locked_by: nil, run_at: run_at, attempts: attempts,
                                       last_error: describe(error))
        end

        def fail(id, attempts:, error:)
          return complete(id) unless Jobs.config.keep_failed

          dataset.where(id: id).update(locked_at: nil, locked_by: nil, failed_at: Sequel::CURRENT_TIMESTAMP,
                                       attempts: attempts, last_error: describe(error))
        end

        # Releases this worker's claimed jobs (graceful shutdown).
        def release(worker) = dataset.where(locked_by: worker).update(locked_at: nil, locked_by: nil)

        # Releases jobs locked longer than `timeout` seconds (their worker died).
        def release_stale(timeout)
          cutoff = Sequel.lit("CURRENT_TIMESTAMP - make_interval(secs => ?)", Float(timeout))
          dataset.where { locked_at < cutoff }.update(locked_at: nil, locked_by: nil)
        end

        # Failed jobs back to the queue: all, or the given ids.
        def retry_failed(ids = nil)
          failed = dataset.exclude(failed_at: nil)
          failed = failed.where(id: ids) if ids
          failed.update(failed_at: nil, attempts: 0, run_at: Sequel::CURRENT_TIMESTAMP, last_error: nil)
        end

        def discard_failed(ids = nil)
          failed = dataset.exclude(failed_at: nil)
          failed = failed.where(id: ids) if ids
          failed.delete
        end

        def failed(limit: 20)
          dataset.exclude(failed_at: nil).order(Sequel.desc(:failed_at)).limit(limit)
                 .select(:id, :queue, :job_class, :attempts, :failed_at, :last_error).all
        end

        # { "default" => { ready:, scheduled:, running:, failed: }, ... }
        def stats
          now = Sequel::CURRENT_TIMESTAMP
          states = Sequel.case(
            [[Sequel.~(failed_at: nil), "failed"], [Sequel.~(locked_at: nil), "running"],
             [Sequel[:run_at] > now, "scheduled"]], "ready"
          )
          dataset.group_and_count(:queue, states.as(:state)).all.each_with_object({}) do |row, result|
            (result[row[:queue]] ||= { ready: 0, scheduled: 0, running: 0, failed: 0 })[row[:state].to_sym] =
              row[:count]
          end
        end

        private

        # args as text, parsed with the json gem: jobs receive plain Hash/Array
        # values rather than Sequel's JSONB wrappers. (Lazy: Sequel may not be loaded.)
        def returned_columns
          @returned_columns ||= [:id, :job_class, :queue, :priority, :attempts,
                                 Sequel.cast(:args, :text).as(:args_json)].freeze
        end

        def payload_for(row)
          { "id" => row[:id], "job_class" => row[:job_class], "queue" => row[:queue],
            "priority" => row[:priority], "args" => JSON.parse(row[:args_json]), "attempts" => row[:attempts] }
        end

        def describe(error)
          "#{error.class}: #{error.message}\n#{Array(error.backtrace).first(20).join("\n")}"[0, 10_000]
        end
      end
    end
  end
end
