# frozen_string_literal: true

require "argon2"

module GemStack
  module Auth
    # Password hashing with Argon2id (DECISIONS D-049). Hashes from other
    # systems in bcrypt format still verify (add gem "bcrypt") and are
    # upgraded to Argon2id on the next successful login.
    module Password
      class << self
        def create(plain)
          config = Auth.config
          Argon2::Password.new(t_cost: config.argon2_t_cost, m_cost: config.argon2_m_cost, p_cost: 1).create(plain)
        end

        def verify(plain, digest)
          return false unless plain.is_a?(String) && digest.is_a?(String)
          return false if plain.bytesize > 1024 # never spend hashing time on megabyte "passwords"

          if digest.start_with?("$argon2")
            Argon2::Password.verify_password(plain, digest)
          elsif digest.match?(/\A\$2[aby]\$/)
            bcrypt.new(digest) == plain
          else
            false
          end
        rescue Argon2::ArgonHashFail
          false
        end

        # True for bcrypt hashes and Argon2 hashes weaker than the current settings.
        def needs_rehash?(digest)
          match = digest.to_s.match(/\A\$argon2id\$v=\d+\$m=(\d+),t=(\d+),p=\d+\$/) or return true
          config = Auth.config
          match[1].to_i < (1 << config.argon2_m_cost) || match[2].to_i < config.argon2_t_cost
        end

        # Spends the same time as a real verification, so "no such user" and
        # "wrong password" can't be told apart by timing.
        def verify_dummy(plain)
          @dummy ||= create(SecureRandom.hex(16))
          verify(plain.to_s[0, 1024], @dummy)
          false
        end

        # Validation messages for a new password (length only, per NIST SP 800-63B).
        def errors(plain)
          config = Auth.config
          length = plain.to_s.length
          if plain.to_s.strip.empty?
            ["is required"]
          elsif length < config.password_min_length
            ["is too short (minimum #{config.password_min_length} characters)"]
          elsif length > config.password_max_length
            ["is too long (maximum #{config.password_max_length} characters)"]
          else
            []
          end
        end

        def reset_dummy! = @dummy = nil

        private

        def bcrypt
          require "bcrypt"
          BCrypt::Password
        rescue LoadError
          raise ConfigurationError, "this password hash is bcrypt; add gem \"bcrypt\" to verify it"
        end
      end
    end
  end
end
