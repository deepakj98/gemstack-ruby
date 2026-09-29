# frozen_string_literal: true

require "test_helper"
require "bcrypt"

class PasswordTest < Minitest::Test
  Password = GemStack::Auth::Password

  def test_argon2id_round_trip
    digest = Password.create("correct horse battery staple")

    assert_match(/\A\$argon2id\$v=19\$m=256,t=1,p=1\$/, digest)
    assert Password.verify("correct horse battery staple", digest)
    refute Password.verify("correct horse battery stapl", digest)
    refute Password.verify(nil, digest)
    refute Password.verify("x", "garbage")
    refute Password.verify("x" * 2000, digest)
  end

  def test_production_costs
    config = GemStack::Auth::Config.new
    GemStack.stub(:env, GemStack::Environment.new("production")) do
      assert_equal [2, 15], [config.argon2_t_cost, config.argon2_m_cost]
    end
  end

  def test_needs_rehash
    refute Password.needs_rehash?(Password.create("x" * 12))
    assert Password.needs_rehash?("$argon2id$v=19$m=64,t=1,p=1$c2FsdHNhbHQ$aGFzaA")
    assert Password.needs_rehash?(BCrypt::Password.create("x", cost: 4).to_s)
  end

  def test_verifies_legacy_bcrypt
    require "bcrypt"
    legacy = BCrypt::Password.create("old password here", cost: 4).to_s

    assert Password.verify("old password here", legacy)
    refute Password.verify("wrong", legacy)
  end

  def test_errors
    assert_equal ["is required"], Password.errors(nil)
    assert_equal ["is too short (minimum 12 characters)"], Password.errors("short")
    assert_equal ["is too long (maximum 128 characters)"], Password.errors("x" * 129)
    assert_empty Password.errors("a perfectly fine passphrase")
  end

  def test_dummy_verification_is_false
    refute Password.verify_dummy("anything at all")
  end
end
