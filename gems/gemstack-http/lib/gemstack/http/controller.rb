# frozen_string_literal: true

module GemStack
  module HTTP
    # Base class for API controllers.
    #
    #   class ProductsController < ApplicationController
    #     before :load_product, only: %i[show update]
    #     rescue_from Payments::Declined, status: 402
    #
    #     def index = render(Product.all)
    #     def show = render(@product)
    #
    #     def create
    #       product = Product.create!(params.require(:product).permit(:name, :price))
    #       render product, status: :created
    #     end
    #
    #     private
    #
    #     def load_product = @product = Product.find(params[:id])
    #   end
    #
    # Actions are the public methods defined in subclasses. An action that
    # doesn't render responds 204 No Content. A `before` callback that
    # renders halts the chain and the action is skipped.
    class Controller
      class DoubleRenderError < Error; end
      class ActionNotFound < Error; end

      Callback = Struct.new(:callback_method, :block, :only, :except) do
        def applies?(action)
          (only.nil? || only.include?(action)) && (except.nil? || !except.include?(action))
        end
      end

      RescueHandler = Struct.new(:classes, :handler, :status, :code)

      class << self
        def before_callbacks = @before_callbacks ||= inherited_copy(:before_callbacks)
        def after_callbacks = @after_callbacks ||= inherited_copy(:after_callbacks)
        def rescue_handlers = @rescue_handlers ||= inherited_copy(:rescue_handlers)

        # before :authenticate, only: %i[create update]
        # before { render({ error: "..." }, status: 401) unless ok? }
        def before(*methods, only: nil, except: nil, &block)
          add_callbacks(before_callbacks, methods, block, only, except)
        end

        def after(*methods, only: nil, except: nil, &block)
          add_callbacks(after_callbacks, methods, block, only, except)
        end

        def skip_before(*methods)
          names = methods.map(&:to_sym)
          @before_callbacks = before_callbacks.reject { |cb| names.include?(cb.callback_method) }
        end

        # rescue_from Stripe::CardError, with: :card_declined
        # rescue_from Timeout::Error, status: 504, code: "upstream_timeout"
        # rescue_from(MyError) { |error| render({ message: error.message }, status: 400) }
        # Later declarations take precedence (they are checked first).
        def rescue_from(*classes, with: nil, status: nil, code: nil, &block)
          handler = with || block
          raise ArgumentError, "rescue_from needs with:, a block, or status:" unless handler || status

          rescue_handlers.unshift(RescueHandler.new(classes, handler, status, code))
        end

        # Declares the request schema for actions; `input` returns the
        # validated, coerced data inside those actions (DECISIONS D-021).
        #
        #   accepts :create, with: Product.input_schema
        #   accepts :update, with: Product.input_schema, partial: true
        #   accepts(:search) { required :q, :string }
        def accepts(*actions, with: nil, partial: false, &)
          schema = with || Schema.define(&)
          raise ArgumentError, "accepts needs with: SchemaClass or a block" unless schema

          schema = schema.partial if partial
          actions.each { |action| input_schemas[action.to_s] = schema }
        end

        def input_schemas = @input_schemas ||= inherited_copy(:input_schemas, {})

        # Declares an action's response type for the API contract when the
        # convention (<Resource>Serializer, see docs/typescript.md) doesn't apply:
        #   returns :search, [ProductSerializer]
        #   returns :stats, StatsSerializer
        #   returns :ping, nil          # no body
        def returns(*actions, type)
          actions.each { |action| response_types[action.to_s] = type }
        end

        def response_types = @response_types ||= inherited_copy(:response_types, {})

        # Public instance methods added by subclasses of Controller.
        def action_methods
          @action_methods ||= (public_instance_methods(true) - Controller.public_instance_methods(true))
                              .to_set(&:to_s).freeze
        end

        def method_added(name)
          super
          @action_methods = nil
        end

        def dispatch(action, env)
          raise ActionNotFound, "#{name}##{action} is not a public action" unless action_methods.include?(action)

          new(env).process(action)
        end

        private

        def inherited_copy(name, empty = [])
          superclass.respond_to?(name) ? superclass.public_send(name).dup : empty
        end

        def add_callbacks(list, methods, block, only, except)
          only &&= Array(only).map(&:to_s)
          except &&= Array(except).map(&:to_s)
          methods.each { |m| list << Callback.new(m.to_sym, nil, only, except) }
          list << Callback.new(nil, block, only, except) if block
        end
      end

      attr_reader :env, :request, :action_name

      def initialize(env)
        @env = env
        @request = Request.new(env)
        @response = nil
        @response_headers = {}
      end

      def params
        @params ||= Params.new(request.all_params)
      end

      # The validated input for the current action, as declared with `accepts`.
      def input
        @input ||= begin
          schema = self.class.input_schemas[action_name] or
            raise Error, "#{self.class.name}##{action_name} has no `accepts` declaration; use params.validate instead"
          schema.call(params)
        end
      end

      # Headers to add to the response. Set them before or after rendering.
      def headers = @response_headers

      def logger = GemStack.logger

      def rendered? = !@response.nil?

      # Renders value as JSON.
      #   render product
      #   render products, status: :ok
      #   render({ ok: true }, status: 202, headers: { "cache-control" => "no-store" })
      #   render product, serializer: Admin::ProductSerializer
      def render(value = nil, status: 200, headers: {}, serializer: nil)
        raise DoubleRenderError, "render/head called twice in #{self.class.name}##{action_name}" if rendered?

        @response_headers.merge!(headers)
        @response_headers["content-type"] ||= "application/json; charset=utf-8"
        body = serializer ? apply_serializer(serializer, value) : serialize(value)
        @response = [status_code(status), [codec.dump(body)]]
      end

      # Responds without a body: head :no_content, head 404
      def head(status, headers = {})
        raise DoubleRenderError, "render/head called twice in #{self.class.name}##{action_name}" if rendered?

        @response_headers.merge!(headers)
        @response = [status_code(status), []]
      end

      # Turns domain objects into JSON-ready structures. By convention an
      # object of class Product is rendered with ProductSerializer (also for
      # arrays and datasets of them). Values without a serializer go to the
      # JSON codec as they are. Override for custom behaviour.
      def serialize(value)
        case value
        when Hash, String, Numeric, Symbol, true, false, nil then value
        when Array
          serializer = value.first && Serializer.for(value.first.class)
          serializer ? serializer.many(value, serializer_context) : value
        else
          if value.respond_to?(:model) && value.respond_to?(:all) # a dataset / query
            serializer = Serializer.for(value.model)
            return serializer ? serializer.many(value, serializer_context) : value.all
          end
          serializer = Serializer.for(value.class)
          serializer ? serializer.serialize(value, serializer_context) : value
        end
      end

      # Passed to serializers as `context` (e.g. { current_user: current_user }).
      def serializer_context = {}

      def process(action)
        @action_name = action
        run_callbacks(self.class.before_callbacks)
        public_send(action) unless rendered?
        run_callbacks(self.class.after_callbacks)
        finish
      rescue StandardError => e
        handle_exception(e)
        finish
      end

      private

      def finish
        head(:no_content) unless rendered?
        status, body = @response
        [status, @response_headers, body]
      end

      def run_callbacks(callbacks)
        callbacks.each do |callback|
          next unless callback.applies?(@action_name)

          callback.callback_method ? send(callback.callback_method) : instance_exec(&callback.block)
          break if rendered? && callbacks.equal?(self.class.before_callbacks)
        end
      end

      def handle_exception(error)
        rescuer = self.class.rescue_handlers.find { |h| h.classes.any? { |klass| error.is_a?(klass) } }
        raise error unless rescuer

        @response = nil
        @response_headers = @response_headers.slice("x-request-id")
        if rescuer.handler
          rescuer.handler.is_a?(Proc) ? instance_exec(error, &rescuer.handler) : call_handler(rescuer.handler, error)
        else
          status = status_code(rescuer.status)
          wrapped = GemStack::Error.new(error.message, status: status,
                                                       code: rescuer.code || ErrorRenderer.code_for(status))
          status, headers, body = ErrorRenderer.render(wrapped, request_id: request.request_id)
          @response_headers.merge!(headers)
          @response = [status, body]
        end
      end

      def apply_serializer(serializer, value)
        list = value.is_a?(Array) || (value.respond_to?(:all) && value.respond_to?(:model))
        list ? serializer.many(value, serializer_context) : serializer.serialize(value, serializer_context)
      end

      def call_handler(name, error)
        method(name).arity.zero? ? send(name) : send(name, error)
      end

      def status_code(status)
        return status if status.is_a?(Integer)

        Rack::Utils::SYMBOL_TO_STATUS_CODE.fetch(status.to_sym) { raise ArgumentError, "unknown status #{status}" }
      end

      def codec = env[JSON_CODEC] || JSONCodec.default
    end
  end
end
