# frozen_string_literal: true

module GemStack
  module Auth
    # Password and email behaviour for the user model:
    #
    #   class User < GemStack::Model
    #     include GemStack::Auth::User
    #   end
    #
    #   User.create(email: "Ada@Example.com", password: "correct horse battery")
    #   User.authenticate_by(email: "ada@example.com", password: "…")  # => user or nil
    #
    # Needs the columns email (unique) and password_digest; email_verified_at
    # for verification.
    module User
      EMAIL_FORMAT = /\A[^@\s]+@[^@\s.]+(\.[^@\s.]+)+\z/

      def self.included(model) = model.extend(ClassMethods)

      module ClassMethods
        def normalize_email(email) = email.to_s.unicode_normalize(:nfkc).strip.downcase

        # The user when the password matches; nil otherwise, in about the same
        # time whether or not the email exists.
        def authenticate_by(email:, password:)
          user = first(email: normalize_email(email))
          return user if user&.authenticate(password)

          Password.verify_dummy(password) unless user
          nil
        end
      end

      attr_reader :password

      def email=(value)
        self[:email] = value.nil? ? nil : self.class.normalize_email(value)
      end

      # Hashed right away (when the length is acceptable); the plain text is
      # kept in memory only for validation.
      def password=(plain)
        @password = plain
        self[:password_digest] = Password.errors(plain).empty? ? Password.create(plain) : nil
      end

      # Verifies a password; upgrades the stored hash when the settings changed.
      def authenticate(plain)
        return false unless Password.verify(plain, self[:password_digest])

        if Password.needs_rehash?(self[:password_digest])
          digest = Password.create(plain)
          this.update(password_digest: digest)
          self[:password_digest] = digest
        end
        true
      end

      def email_verified? = !self[:email_verified_at].nil?

      def validate
        super
        errors.add(:email, "is invalid") unless self[:email].to_s.match?(EMAIL_FORMAT) || errors.on(:email)
        Password.errors(@password).each { |message| errors.add(:password, message) } if new? || !@password.nil?
        return unless self[:email] && (new? || changed_columns.include?(:email))

        validates_unique(:email,
                         message: "is already taken")
      end
    end
  end
end
