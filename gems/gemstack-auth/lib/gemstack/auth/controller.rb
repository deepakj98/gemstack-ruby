# frozen_string_literal: true

module GemStack
  module Auth
    # Authentication for controllers:
    #
    #   class ApplicationController < GemStack::Controller
    #     include GemStack::Auth::Controller
    #   end
    #
    #   class OrdersController < ApplicationController
    #     before :require_login
    #     def index = render(current_user.orders_dataset)
    #   end
    #
    # A request is authenticated by the session cookie (browsers) or by
    # `Authorization: Bearer <api token>` (scripts, other services).
    #
    # Cross-site request forgery: state-changing requests (POST, PUT, PATCH,
    # DELETE) from other sites are refused with 403 unless the origin is in
    # config.auth.trusted_origins. Browsers label every request with
    # Sec-Fetch-Site / Origin; clients that send neither (curl, servers) are
    # not browsers and can't carry a victim's cookie (DECISIONS D-051).
    module Controller
      SAFE_METHODS = %w[GET HEAD OPTIONS].freeze

      def self.included(base)
        base.include(RateLimit)
        base.include(Policy::Authorization)
        base.before :verify_request_origin
      end

      # The signed-in user, or nil.
      def current_user
        return @current_user if defined?(@current_user)

        @current_user = authenticate_request
      end

      def signed_in? = !current_user.nil?

      # :session, :token, or nil.
      def authenticated_by
        current_user
        @authenticated_by
      end

      # The current `sessions` row (cookie authentication only).
      def current_session
        current_user
        @current_session
      end

      # before :require_login — 401 for anonymous requests.
      def require_login
        raise Unauthorized.new("Sign in to continue.", code: "unauthenticated") unless current_user
      end

      # Starts a session: a new token (never reuses one the browser already
      # had, which would allow session fixation) in an HttpOnly cookie.
      def sign_in(user)
        Sessions.revoke(session_cookie) if session_cookie
        token = Sessions.create(user.id, ip: request.ip, user_agent: request.user_agent)
        write_session_cookie(token)
        @current_session = Sessions.find(token)
        @authenticated_by = :session
        @current_user = user
      end

      def sign_out
        Sessions.revoke(session_cookie) if session_cookie
        delete_session_cookie
        @current_session = nil
        @authenticated_by = nil
        @current_user = nil
      end

      private

      def authenticate_request
        if (token = bearer_token)
          row = Tokens.find(token, purpose: "api") or return nil
          @authenticated_by = :token
          Auth.user_class[row[:user_id]]
        elsif (token = session_cookie)
          session = Sessions.find(token)
          unless session
            delete_session_cookie # expired or revoked: stop sending it
            return nil
          end

          write_session_cookie(token) if session[:touched] # slide the cookie's expiry too
          @current_session = session
          @authenticated_by = :session
          Auth.user_class[session[:user_id]]
        end
      end

      def bearer_token
        header = request.get_header("HTTP_AUTHORIZATION").to_s
        header[/\ABearer\s+(\S+)\z/i, 1]
      end

      def session_cookie
        value = request.cookies[Auth.config.cookie_name]
        value.nil? || value.empty? ? nil : value
      end

      def write_session_cookie(token)
        config = Auth.config
        replace_cookie(Rack::Utils.set_cookie_header(
                         config.cookie_name,
                         value: token, path: "/", httponly: true, secure: config.cookie_secure,
                         same_site: config.cookie_same_site, max_age: config.session_ttl.to_s
                       ))
      end

      def delete_session_cookie
        config = Auth.config
        replace_cookie(Rack::Utils.set_cookie_header(
                         config.cookie_name,
                         value: "", path: "/", httponly: true, secure: config.cookie_secure,
                         same_site: config.cookie_same_site, max_age: "0", expires: Time.at(0)
                       ))
      end

      def replace_cookie(line)
        existing = headers["set-cookie"]
        name = line[/\A[^=]+/]
        kept = Array(existing).reject { |cookie| cookie.start_with?("#{name}=") }
        headers["set-cookie"] = kept.empty? ? line : kept + [line]
      end

      def verify_request_origin
        return if SAFE_METHODS.include?(request.request_method)
        return if bearer_token && !session_cookie # custom headers can't be sent cross-site without CORS
        return if same_origin_request?

        raise Forbidden.new("Cross-site request refused.", code: "cross_site_request")
      end

      def same_origin_request?
        origin = request.get_header("HTTP_ORIGIN")
        return true if origin && Array(Auth.config.trusted_origins).include?(origin)

        site = request.get_header("HTTP_SEC_FETCH_SITE")
        return %w[same-origin none].include?(site) if site
        return true if origin.nil? || origin.empty?

        hosts = [request.host_with_port, request.get_header("HTTP_X_FORWARDED_HOST")].compact
        host = URI.parse(origin).then { |uri| [uri.host, uri.port].join(":") }
        hosts.any? { |value| normalize_host(value, origin) == host }
      rescue URI::InvalidURIError
        false
      end

      def normalize_host(value, origin)
        host, port = value.split(",").first.strip.split(":", 2)
        port ||= origin.start_with?("https:") ? "443" : "80"
        "#{host}:#{port}"
      end
    end
  end
end
