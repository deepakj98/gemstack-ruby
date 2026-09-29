# frozen_string_literal: true

module GemStack
  # Authorization rules, one policy class per model (DECISIONS D-052):
  #
  #   class OrderPolicy < GemStack::Policy
  #     def show? = owner? || user&.admin?
  #     def update? = owner?
  #
  #     class Scope < Scope
  #       def resolve = user&.admin? ? scope : scope.where(user_id: user&.id)
  #     end
  #
  #     private
  #
  #     def owner? = user && record.user_id == user.id
  #   end
  #
  #   class OrdersController < ApplicationController
  #     def index = render(paginate(policy_scope(Order.order(:id))))
  #     def show = render(authorize!(Order.find(params[:id])))   # OrderPolicy#show?
  #   end
  #
  # Everything is denied unless a policy method says otherwise.
  class Policy
    class NotDefined < Error; end

    attr_reader :user, :record

    def initialize(user, record)
      @user = user
      @record = record
    end

    def index? = false
    def show? = false
    def create? = false
    def update? = false
    def destroy? = false

    # Narrows a dataset to the records the user may see.
    class Scope
      attr_reader :user, :scope

      def initialize(user, scope)
        @user = user
        @scope = scope
      end

      def resolve
        raise NotDefined, "#{self.class.name}#resolve is not defined; it decides which records a user may list"
      end
    end

    # The policy class for a record, a model class or a dataset: Order,
    # Order.where(...) and an order all use OrderPolicy.
    def self.for(subject)
      model = if subject.is_a?(Class) then subject
              elsif subject.respond_to?(:model) && subject.model.is_a?(Class) then subject.model
              else subject.class
              end
      name = "#{model.name}Policy"
      Object.const_get(name)
    rescue NameError => e
      raise unless e.name.to_s == name.split("::").last || e.name.to_s == name

      raise NotDefined, "#{name} is not defined (create app/policies/#{Inflector.underscore(name)}.rb " \
                        "or run `gemstack generate policy #{model.name}`)"
    end

    # Controller helpers (included with GemStack::Auth::Controller by `gemstack add auth`).
    module Authorization
      # Returns the record when allowed; 403 otherwise. The rule defaults to
      # "<action>?" (show → show?); a custom action maps to its own name.
      def authorize!(record, rule = nil, policy: nil)
        rule ||= :"#{action_name}?"
        allowed = (policy || Policy.for(record)).new(policy_user, record).public_send(rule)
        return record if allowed

        raise Forbidden.new("You are not allowed to do that.", code: "forbidden")
      end

      def policy_scope(scope, policy: nil) = (policy || Policy.for(scope))::Scope.new(policy_user, scope).resolve

      def policy(record) = Policy.for(record).new(policy_user, record)

      private

      def policy_user = respond_to?(:current_user) ? current_user : nil
    end
  end
end
