# frozen_string_literal: true

module GemStack
  module DB
    # Gives Sequel/PostgreSQL errors their HTTP meaning via GemStack::ErrorMapping
    # (no dependency on the HTTP layer):
    #
    #   record not found           → 404 not_found
    #   model validation failed    → 422 validation_failed + field errors
    #   unique / not-null / FK     → 422 with the offending column when PostgreSQL reports it
    #   row still referenced (FK)  → 409 conflict
    #   database unreachable       → 503 service_unavailable
    module Errors
      KEY_DETAIL = /Key \(([^)]+)\)=/

      module_function

      def install!
        install_record_errors!
        install_constraint_errors!
        ErrorMapping.register(Sequel::DatabaseConnectionError) { ServiceUnavailable.new("Database unavailable") }
        ErrorMapping.register(Sequel::PoolTimeout) { ServiceUnavailable.new("Database busy, try again") }
      end

      def install_record_errors!
        ErrorMapping.register(Sequel::NoMatchingRow) do |error|
          model = error.respond_to?(:dataset) && error.dataset.respond_to?(:model) ? error.dataset.model : nil
          RecordNotFound.new(model&.name ? "#{model.name} not found" : "Record not found")
        end
        ErrorMapping.register(Sequel::ValidationFailed) do |error|
          ValidationError.new(errors: stringify(error.errors))
        end
        ErrorMapping.register(Sequel::InvalidValue) do |error|
          ValidationError.new(error.message.sub(/\A.*?: /, "Invalid value: "), code: "invalid_value")
        end
        ErrorMapping.register(Sequel::MassAssignmentRestriction) do |error|
          BadRequest.new(error.message, code: "unknown_attribute")
        end
      end

      def install_constraint_errors!
        ErrorMapping.register(Sequel::UniqueConstraintViolation) do |error|
          field_error(columns(error), "is already taken") || Conflict.new("Record already exists")
        end
        ErrorMapping.register(Sequel::NotNullConstraintViolation) do |error|
          field_error([column(error)].compact, "is required") || ValidationError.new("A required value is missing")
        end
        ErrorMapping.register(Sequel::ForeignKeyConstraintViolation) do |error|
          if error.message.include?("is not present")
            field_error(columns(error), "does not exist") || ValidationError.new("A referenced record does not exist")
          else
            Conflict.new("Record is still referenced by other records", code: "still_referenced")
          end
        end
        ErrorMapping.register(Sequel::CheckConstraintViolation) do
          ValidationError.new("A value violates a database constraint", code: "constraint_violation")
        end
      end

      def stringify(errors) = errors.to_h { |key, messages| [Array(key).join(","), Array(messages)] }

      def field_error(names, message)
        return nil if names.empty?

        ValidationError.new(errors: names.to_h { |name| [name, [message]] })
      end

      def pg_error(error) = error.respond_to?(:wrapped_exception) ? error.wrapped_exception : nil

      def columns(error)
        if defined?(PG::PG_DIAG_MESSAGE_DETAIL)
          detail = pg_error(error)&.result&.error_field(PG::PG_DIAG_MESSAGE_DETAIL)
        end
        detail ||= error.message
        match = KEY_DETAIL.match(detail.to_s)
        match ? match[1].split(",").map(&:strip).map { |c| c.delete('"') } : []
      rescue StandardError
        []
      end

      def column(error)
        pg_error(error)&.result&.error_field(PG::PG_DIAG_COLUMN_NAME) ||
          error.message[/column "([^"]+)"/, 1]
      rescue StandardError
        nil
      end
    end
  end
end

GemStack::DB::Errors.install!
