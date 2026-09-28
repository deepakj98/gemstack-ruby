# frozen_string_literal: true

# Test-only settings. config/app.rb applies to every environment.
GemStack.configure do |config|
  # Logs are discarded in tests unless GEMSTACK_LOG_LEVEL is set, e.g.:
  # config.logger.level = :debug
end
