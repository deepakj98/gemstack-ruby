# frozen_string_literal: true

module GemStack
  module Auth
    # Tokens in the `auth_tokens` table:
    #   "api"                 long-lived bearer tokens (Authorization: Bearer gs_…)
    #   "password_reset"      single use, short-lived, emailed
    #   "email_verification"  single use, emailed, bound to the address it was sent to
    module Tokens
      PURPOSES = %w[api password_reset email_verification].freeze
      PREFIX = { "api" => "gs_" }.freeze
      # last_used_at is written at most once a minute per token.
      TOUCH_INTERVAL = 60

      class << self
        def dataset = Auth.db[:auth_tokens]

        # Returns [token, row id]. The plain token is shown to the user once
        # and never stored. Issuing a reset/verification token invalidates the
        # user's earlier ones for the same purpose.
        def issue(user_id, purpose:, name: nil, email: nil, expires_in: default_ttl(purpose))
          check_purpose!(purpose)
          dataset.where(user_id: user_id, purpose: purpose).delete unless purpose == "api"
          token = Token.generate(PREFIX.fetch(purpose, ""))
          now = Time.now
          id = dataset.insert(user_id: user_id, purpose: purpose, token_digest: Token.digest(token), name: name,
                              email: email, created_at: now, expires_at: expires_in && (now + expires_in))
          [token, id]
        end

        # The live token row, or nil. API tokens record when they were last used.
        def find(token, purpose:)
          check_purpose!(purpose)
          return nil unless Token.plausible?(token)

          now = Time.now
          row = live(token, purpose, now).first or return nil
          if purpose == "api" && (row[:last_used_at].nil? || row[:last_used_at] <= now - TOUCH_INTERVAL)
            dataset.where(id: row[:id]).update(last_used_at: now)
          end
          row
        end

        # Uses up a single-use token: deletes and returns its row, atomically,
        # so two concurrent requests can't both use one reset link.
        def consume(token, purpose:)
          check_purpose!(purpose)
          return nil unless Token.plausible?(token)

          live(token, purpose, Time.now).returning.delete.first
        end

        def revoke(id, user_id:) = dataset.where(id: id, user_id: user_id).delete.positive?
        def revoke_all(user_id, purpose:) = dataset.where(user_id: user_id, purpose: purpose).delete

        def for_user(user_id, purpose: "api")
          dataset.where(user_id: user_id, purpose: purpose).order(Sequel.desc(:created_at))
                 .select(:id, :name, :created_at, :last_used_at, :expires_at).all
        end

        private

        def live(token, purpose, now)
          dataset.where(token_digest: Token.digest(token), purpose: purpose)
                 .where(Sequel.|({ expires_at: nil }, Sequel[:expires_at] > now))
        end

        def default_ttl(purpose)
          config = Auth.config
          { "api" => config.api_token_ttl, "password_reset" => config.password_reset_ttl,
            "email_verification" => config.email_verification_ttl }.fetch(purpose)
        end

        def check_purpose!(purpose)
          raise ArgumentError, "unknown token purpose #{purpose.inspect}" unless PURPOSES.include?(purpose)
        end
      end
    end
  end
end
