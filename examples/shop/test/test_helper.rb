# frozen_string_literal: true

ENV["GEMSTACK_ENV"] = "test"

require_relative "../config/app"
require "gemstack/testing"
require "gemstack/db/testing"
require "minitest/autorun"

# Creates the test database (TEST_DATABASE_URL) if needed and applies migrations.
GemStack::DB::Testing.prepare!
GemStack.boot!

# Every test runs in a transaction that is rolled back afterwards.
GemStack::TestCase.include GemStack::DB::Testing::Transactions
