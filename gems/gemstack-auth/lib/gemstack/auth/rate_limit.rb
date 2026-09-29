# frozen_string_literal: true

require "digest"

module GemStack
  module Auth
    # Fixed-window rate limits for controller actions, counted in
    # GemStack.cache (use a shared store — :redis — with several servers).
    #
    #   rate_limit to: 10, within: 60, only: :create                        # per client IP
    #   rate_limit to: 3, within: 3600, only: :create, name: "forgot-email",
    #              by: -> { params[:email].to_s.downcase }
    #
    # Over the limit: 429 with Retry-After.
    module RateLimit
      def self.included(base) = base.extend(ClassMethods)

      module ClassMethods
        def rate_limit(to:, within:, by: -> { request.ip }, only: nil, except: nil, name: nil)
          limit = Integer(to)
          period = Integer(within)
          before(only: only, except: except) { enforce_rate_limit(limit, period, by, name) }
        end
      end

      private

      def enforce_rate_limit(limit, period, by, name)
        subject = instance_exec(&by).to_s
        return if subject.empty?

        now = Time.now.to_i
        key = ["rate-limit", name || "#{self.class.name}##{action_name}", Digest::SHA256.hexdigest(subject)[0, 32],
               now / period]
        return if GemStack.cache.increment(key, expires_in: period) <= limit

        retry_after = period - (now % period)
        raise TooManyRequests.new("Too many attempts. Try again in #{retry_after} seconds.",
                                  code: "rate_limited", headers: { "retry-after" => retry_after.to_s })
      end
    end
  end
end
