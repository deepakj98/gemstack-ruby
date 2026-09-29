# frozen_string_literal: true

require "test_helper"

class AuthAppController < GemStack::HTTP::Controller
  include GemStack::Auth::Controller

  before :require_login, only: %w[me logout_everywhere]
  rate_limit to: 2, within: 60, only: "login"

  def login
    user = User.authenticate_by(email: params[:email], password: params[:password])
    raise GemStack::Unauthorized.new("Invalid email or password", code: "invalid_credentials") unless user

    sign_in(user)
    render({ id: user.id, via: authenticated_by })
  end

  def me = render({ id: current_user.id, via: authenticated_by, session: !current_session.nil? })

  def logout = sign_out

  def logout_everywhere = GemStack::Auth::Sessions.revoke_all(current_user.id)

  def note = render(authorize!(Note.new(params[:owner_id].to_i)).to_h)

  def notes = render(policy_scope([Note.new(current_user&.id), Note.new(-1)], policy: NotePolicy).map(&:to_h))
end

Note = Struct.new(:owner_id)

class NotePolicy < GemStack::Policy
  def note? = user && record.owner_id == user.id

  class Scope < Scope
    def resolve = scope.select { |note| user && note.owner_id == user.id }
  end
end

class ControllerTest < AuthTestCase
  include Rack::Test::Methods
  include GemStack::Auth::Testing

  def app
    @app ||= GemStack::HTTP::App.new(
      config: GemStack::HTTP::Config.new,
      router: GemStack::HTTP::Router.new(prefix: "/api").draw do
        post "/login", to: "auth_app#login"
        get "/me", to: "auth_app#me"
        delete "/logout", to: "auth_app#logout"
        delete "/sessions", to: "auth_app#logout_everywhere"
        get "/note", to: "auth_app#note"
        get "/notes", to: "auth_app#notes"
      end
    )
  end

  def setup
    super
    @cache = GemStack.cache
    GemStack.cache = GemStack::Cache::MemoryStore.new
  end

  def teardown
    GemStack.cache = @cache
    super
  end

  def json = JSON.parse(last_response.body)

  def login(email = "ada@example.com", password = PASSWORD, headers = {})
    post "/api/login", JSON.generate(email: email, password: password),
         { "CONTENT_TYPE" => "application/json" }.merge(headers)
  end

  def test_login_sets_a_hardened_session_cookie
    user = create_user
    login

    assert_equal 200, last_response.status
    cookie = last_response.headers["set-cookie"]
    assert_match(%r{\Agemstack_session=[\w-]{43}; path=/; max-age=2592000; httponly; samesite=lax\z}i, cookie)
    get "/api/me"

    assert_equal({ "id" => user.id, "via" => "session", "session" => true }, json)
  end

  def test_production_cookie_is_secure_and_host_prefixed
    config = GemStack::Auth::Config.new
    GemStack.stub(:env, GemStack::Environment.new("production")) do
      assert config.cookie_secure
      assert_equal "__Host-session", config.cookie_name
    end
  end

  def test_anonymous_and_bad_credentials
    create_user
    get "/api/me"

    assert_equal 401, last_response.status
    assert_equal "unauthenticated", json.dig("error", "code")
    login("ada@example.com", "wrong password!!")

    assert_equal 401, last_response.status
    assert_nil last_response.headers["set-cookie"]
  end

  def test_sign_in_replaces_an_existing_session
    create_user
    login
    login

    assert_equal 1, GemStack::Auth::Sessions.dataset.count
  end

  def test_logout_revokes_the_session_and_clears_the_cookie
    create_user
    login
    stolen = rack_mock_session.cookie_jar["gemstack_session"]
    delete "/api/logout"

    assert_equal 204, last_response.status
    assert_match(%r{gemstack_session=; path=/; max-age=0;}, last_response.headers["set-cookie"])
    assert_equal 0, GemStack::Auth::Sessions.dataset.count
    set_cookie("gemstack_session=#{stolen}")
    get "/api/me"

    assert_equal 401, last_response.status, "a copied cookie is dead after logout"
  end

  def test_revoke_all_sessions
    user = create_user
    other_device = GemStack::Auth::Sessions.create(user.id)
    sign_in_as(user)
    delete "/api/sessions"

    assert_nil GemStack::Auth::Sessions.find(other_device)
  end

  def test_bearer_tokens
    user = create_user
    get "/api/me", {}, bearer_headers(user)

    assert_equal({ "id" => user.id, "via" => "token", "session" => false }, json)
    get "/api/me", {}, { "HTTP_AUTHORIZATION" => "Bearer gs_invalid-token-value-000000000000" }

    assert_equal 401, last_response.status
  end

  def test_cross_site_posts_are_refused
    create_user
    login("ada@example.com", PASSWORD, "HTTP_SEC_FETCH_SITE" => "cross-site", "HTTP_ORIGIN" => "https://evil.test")

    assert_equal 403, last_response.status
    assert_equal "cross_site_request", json.dig("error", "code")
    login("ada@example.com", PASSWORD, "HTTP_ORIGIN" => "https://evil.test")

    assert_equal 403, last_response.status, "Origin alone (older browsers) is checked too"
  end

  def test_same_origin_and_trusted_origins_pass
    create_user
    login("ada@example.com", PASSWORD, "HTTP_SEC_FETCH_SITE" => "same-origin")

    assert_equal 200, last_response.status
    login("ada@example.com", PASSWORD, "HTTP_ORIGIN" => "http://example.org")

    assert_equal 200, last_response.status, "Origin matching Host"
    GemStack.config.auth.trusted_origins = ["https://admin.example.com"]
    login("ada@example.com", PASSWORD, "HTTP_SEC_FETCH_SITE" => "same-site", "HTTP_ORIGIN" => "https://admin.example.com")

    assert_equal 429, last_response.status, "allowed through (and now rate limited)"
  ensure
    GemStack.config.auth.trusted_origins = []
  end

  def test_rate_limit
    create_user
    2.times { login("ada@example.com", "wrong password!!") }
    login

    assert_equal 429, last_response.status
    assert_equal "rate_limited", json.dig("error", "code")
    assert_includes 1..60, last_response.headers["retry-after"].to_i
  end

  def test_policies
    user = create_user
    sign_in_as(user)
    get "/api/note", owner_id: user.id

    assert_equal 200, last_response.status
    get "/api/note", owner_id: user.id + 1

    assert_equal 403, last_response.status
    get "/api/notes"

    assert_equal [{ "owner_id" => user.id }], json
  end

  def test_missing_policy_message
    error = assert_raises(GemStack::Policy::NotDefined) { GemStack::Policy.for(Object.new) }
    assert_includes error.message, "ObjectPolicy is not defined"
  end
end
