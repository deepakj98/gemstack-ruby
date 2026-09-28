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
