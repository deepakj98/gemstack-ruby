# frozen_string_literal: true

require "test_helper"

class UserTest < AuthTestCase
  def test_normalizes_email_and_hashes_password
    user = create_user(" Ada@Example.COM ")

    assert_equal "ada@example.com", user.email
    assert user.password_digest.start_with?("$argon2id$")
    refute_includes user.values.values, PASSWORD
  end

  def test_validations
    user = User.new(email: "not-an-email", password: "short")

    refute user.valid?
    assert_equal ["is invalid"], user.errors[:email]
    assert_equal ["is too short (minimum 12 characters)"], user.errors[:password]

    create_user
    taken = User.new(email: "ADA@example.com", password: PASSWORD)

    refute taken.valid?
    assert_equal ["is already taken"], taken.errors[:email]
  end

  def test_existing_user_without_password_change_is_valid
    user = User[create_user.id]

    assert user.valid?
  end

  def test_authenticate_by
    user = create_user

    assert_equal user.id, User.authenticate_by(email: "ADA@example.com", password: PASSWORD).id
    assert_nil User.authenticate_by(email: "ada@example.com", password: "wrong password!!")
    assert_nil User.authenticate_by(email: "nobody@example.com", password: PASSWORD)
  end

  def test_rehashes_weaker_hashes_on_login
    require "bcrypt"
    user = create_user
    user.this.update(password_digest: BCrypt::Password.create(PASSWORD, cost: 4).to_s)

    assert User.authenticate_by(email: user.email, password: PASSWORD)
    assert User[user.id].password_digest.start_with?("$argon2id$")
  end
end
