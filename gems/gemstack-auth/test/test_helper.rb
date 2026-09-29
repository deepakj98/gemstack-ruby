# frozen_string_literal: true

ENV["GEMSTACK_ENV"] = "test"
require "gemstack/auth"
require "gemstack/auth/testing"
require "gemstack/db/testing"
require "minitest/autorun"
require "rack/test"

GemStack.config.logger.output = nil

# Needs PostgreSQL: GEMSTACK_TEST_DATABASE_URL=postgres://…/gemstack_auth_test
module AuthDB
  URL = ENV.fetch("GEMSTACK_TEST_DATABASE_URL", nil)

  def self.available?
    return @available if defined?(@available)

    @available = URL && begin
      GemStack.config.db.url = URL.sub(%r{/[^/]*\z}, "/gemstack_auth_test")
      GemStack::DB::Tasks.create
      create_tables(GemStack::DB.connection)
      true
    rescue Sequel::DatabaseError, Sequel::DatabaseConnectionError => e
      warn "PostgreSQL unavailable (#{e.message.lines.first.strip}); skipping auth tests"
      false
    end
  end

  # The same tables `gemstack add auth` creates.
  def self.create_tables(db)
    db.drop_table?(:auth_tokens, :sessions, :users)
    db.create_table(:users) do
      primary_key :id, type: :Bignum
      String :email, null: false, unique: true
      String :password_digest, null: false
      column :email_verified_at, :timestamptz
      column :created_at, :timestamptz, null: false
      column :updated_at, :timestamptz, null: false
    end
    db.create_table(:sessions) do
      primary_key :id, type: :Bignum
      foreign_key :user_id, :users, type: :Bignum, null: false, on_delete: :cascade, index: true
      String :token_digest, size: 64, null: false, unique: true
      column :ip, :inet
      String :user_agent
      column :created_at, :timestamptz, null: false
      column :last_seen_at, :timestamptz, null: false
      column :expires_at, :timestamptz, null: false, index: true
    end
    db.create_table(:auth_tokens) do
      primary_key :id, type: :Bignum
      foreign_key :user_id, :users, type: :Bignum, null: false, on_delete: :cascade, index: true
      String :purpose, size: 30, null: false
      String :token_digest, size: 64, null: false, unique: true
      String :name
      String :email
      column :created_at, :timestamptz, null: false
      column :last_used_at, :timestamptz
      column :expires_at, :timestamptz
    end
  end

  def setup
    skip "set GEMSTACK_TEST_DATABASE_URL to run the auth tests" unless AuthDB.available?
    super
  end
end

if AuthDB.available?
  class User < GemStack::Model
    include GemStack::Auth::User
  end
end

class AuthTestCase < Minitest::Test
  include AuthDB
  include GemStack::DB::Testing::Transactions

  PASSWORD = "correct horse battery staple"

  def create_user(email = "ada@example.com", password: PASSWORD) = User.create(email: email, password: password)
end
