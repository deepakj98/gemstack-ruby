# frozen_string_literal: true

module GemStack
  module Auth
    # Browser sessions, one row per signed-in device in the `sessions` table.
    # Being rows (not signed cookies), they can be listed and revoked:
    # signing out everywhere or resetting a password really ends them.
    module Sessions
      class << self
        def dataset = Auth.db[:sessions]

        # Returns the token to put in the cookie.
        def create(user_id, ip: nil, user_agent: nil)
          token = Token.generate
          now = Time.now
          dataset.insert(token_digest: Token.digest(token), user_id: user_id, ip: ip,
                         user_agent: user_agent&.slice(0, 255), created_at: now, last_seen_at: now,
                         expires_at: now + Auth.config.session_ttl)
          token
        end

        # The live session for a token, or nil. Extends the expiry (at most
        # once per session_touch_interval); row[:touched] tells the caller to
        # re-send the cookie with the new expiry.
        def find(token)
          return nil unless Token.plausible?(token)

          now = Time.now
          row = dataset.where(token_digest: Token.digest(token)).where { expires_at > now }.first or return nil
          if row[:last_seen_at] <= now - Auth.config.session_touch_interval
            expires = now + Auth.config.session_ttl
            dataset.where(id: row[:id]).update(last_seen_at: now, expires_at: expires)
            row = row.merge(last_seen_at: now, expires_at: expires, touched: true)
          end
          row
        end

        def revoke(token) = Token.plausible?(token) ? dataset.where(token_digest: Token.digest(token)).delete : 0

        # Ends every session of a user (optionally keeping one, by id).
        def revoke_all(user_id, except: nil)
          scope = dataset.where(user_id: user_id)
          scope = scope.exclude(id: except) if except
          scope.delete
        end

        def for_user(user_id)
          dataset.where(user_id: user_id).where { expires_at > Time.now }.order(Sequel.desc(:last_seen_at)).all
        end
      end
    end
  end
end
