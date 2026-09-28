# frozen_string_literal: true

require_relative "version"
require_relative "settings"
require_relative "environment"
require_relative "dotenv"
require_relative "errors"
require_relative "error_mapping"
require_relative "logger"
require_relative "inflector"
require_relative "plugins"

module GemStack
  # Root configuration. Modules add namespaces to it:
  #   GemStack::Config.namespace(:http, GemStack::HTTP::Config)
  class Config < Settings
    setting :name, default: -> { File.basename(root) }
    setting :root, default: -> { Dir.pwd }

    # .env files loaded at boot, earlier files win. Real ENV always wins.
    setting :env_files, default: lambda {
      env = GemStack.env
      env.local? ? [".env.#{env}.local", ".env.local", ".env.#{env}", ".env"] : []
    }

    # Keys (substring, case-insensitive) masked in logs and error output.
    setting :filter_parameters, default: %w[password passwd secret token api_key apikey authorization cookie
                                            credit_card card_number cvv ssn private_key]

    namespace :logger do
      setting :level, default: -> { ENV.fetch("GEMSTACK_LOG_LEVEL") { GemStack.env.production? ? "info" : "debug" } }
      setting :format, default: -> { GemStack.env.local? ? :pretty : :json }
      # Test logs are discarded unless GEMSTACK_LOG_LEVEL is set explicitly.
      setting :output, default: -> { GemStack.env.test? && !ENV["GEMSTACK_LOG_LEVEL"] ? nil : $stdout }
      # nil = colour when output is a terminal. `gemstack dev` sets
      # GEMSTACK_LOG_COLOR=1 because child output goes through a pipe.
      setting :color, default: -> { ENV["GEMSTACK_LOG_COLOR"]&.then { |v| v == "1" } }
    end
  end

  class << self
    def config
      @config ||= Config.new
    end

    def configure
      yield config
      config
    end

    def env
      @env ||= Environment.detect
    end

    def env=(name)
      @env = name.is_a?(Environment) ? name : Environment.new(name)
    end

    def root
      Pathname.new(config.root)
    end

    # First call in config/app.rb: sets the application root and loads .env
    # files (development/test) before anything reads configuration or ENV.
    def setup(root:)
      config.root = root.to_s
      load_env_files!
      self
    end

    # Idempotent; real ENV variables are never overwritten.
    def load_env_files!
      files = config.env_files.map { |file| File.expand_path(file, config.root) }
      return if @loaded_env_files == files

      Dotenv.load(files)
      @loaded_env_files = files
    end

    def logger
      @logger ||= begin
        settings = config.logger
        Logger.new(settings.output, level: settings.level, format: settings.format,
                                    filter: config.filter_parameters, color: settings.color)
      end
    end

    attr_writer :logger

    # Forget all process-level state. Intended for tests.
    def reset!
      @config = nil
      @env = nil
      @logger = nil
      @loaded_env_files = nil
    end
  end
end
