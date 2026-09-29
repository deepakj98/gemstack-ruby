# frozen_string_literal: true

require "gemstack/auth"

module GemStack
  module Auth
    # Test helpers (added to GemStack::TestCase by `gemstack add auth`):
    #
    #   sign_in_as(user)                     # later requests carry the session cookie
    #   get_json "/api/auth/me"
    #   get_json "/api/orders", {}, bearer_headers(user)
    module Testing
      def sign_in_as(user)
        token = Sessions.create(user.id, ip: "127.0.0.1", user_agent: "test")
        set_cookie("#{Auth.config.cookie_name}=#{token}")
        token
      end

      def api_token_for(user, name: "test") = Tokens.issue(user.id, purpose: "api", name: name).first

      def bearer_headers(user) = { "HTTP_AUTHORIZATION" => "Bearer #{api_token_for(user)}" }
    end
  end
end
