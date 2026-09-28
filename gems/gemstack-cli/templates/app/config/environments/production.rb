# frozen_string_literal: true

# Production-only settings. Defaults here: JSON logs, no exception details in
# responses, eager loading, HSTS on HTTPS requests.
GemStack.configure do |config|
  # config.logger.level = :info
  # config.http.cors.origins = ["https://app.example.com"]   # only if the frontend is on another domain
end
