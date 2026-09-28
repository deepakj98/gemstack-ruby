# frozen_string_literal: true

module GemStack
  # Explicit, typed JSON representations. Nothing is exposed unless listed.
  #
  #   class ProductSerializer < GemStack::Serializer
  #     attributes :id, :name, :price, :active, :created_at   # types inferred from Product's fields
  #     attribute :display_price, :string do |product|
  #       "€#{product.price}"
  #     end
  #     attribute :category, CategorySerializer                 # nested
  #     attribute :reviews, [ReviewSerializer]                  # nested list
  #   end
  #
  #   ProductSerializer.serialize(product)   # => { id: 1, name: "Lamp", price: "9.99", ... }
  #   ProductSerializer.many(products)       # => [ {...}, ... ]
  #
  # Values are dumped by type: decimals become strings, times ISO 8601 UTC.
  # Types come from an explicit type argument, else from the model's field
  # declarations (the model is found by name: ProductSerializer → Product),
  # and drive the generated TypeScript interfaces.
  class Serializer
    Attribute = Struct.new(:name, :type, :block, :nullable, keyword_init: true) do
      def serializer? = type.is_a?(Class) && type <= Serializer
      def list? = type.is_a?(Array)
    end

    CONVENTIONAL_TYPES = { id: [:bigint, false], created_at: [:datetime, false], updated_at: [:datetime, false] }.freeze

    class << self
      def attributes_list
        @attributes_list ||= superclass.respond_to?(:attributes_list) ? superclass.attributes_list.dup : {}
      end

      # attributes :id, :name        (types inferred)
      # attributes name: :string     (explicit)
      def attributes(*names, **typed)
        names.each { |name| attribute(name) }
        typed.each { |name, type| attribute(name, type) }
      end

      def attribute(name, type = nil, nullable: nil, &block)
        if type && !type.is_a?(Array) && !(type.is_a?(Class) && type <= Serializer)
          type = Types::CLASS_ALIASES.fetch(type, type).to_sym
          Types.fetch(type)
        end
        attributes_list[name.to_sym] = Attribute.new(name: name.to_sym, type: type, block: block, nullable: nullable)
        @resolved_attributes = nil
      end

      # The model used for type inference. Defaults to the class named like
      # the serializer without "Serializer" (Admin::ProductSerializer → Admin::Product, then Product).
      def model(klass = nil)
        @model = klass if klass
        return @model if defined?(@model) && @model

        base = name&.delete_suffix("Serializer")
        return nil if base.nil? || base.empty?

        [base, base.split("::").last].uniq.each do |candidate|
          constant = Object.const_get(candidate) if Object.const_defined?(candidate)
          return constant if constant.respond_to?(:gemstack_fields)
        rescue NameError
          next
        end
        nil
      end

      attr_writer :type_name

      # TypeScript/OpenAPI name: ProductSerializer → "Product", Admin::ProductSerializer → "AdminProduct".
      def type_name
        @type_name || (name && name.delete_suffix("Serializer").split("::").join)
      end

      # Attributes with resolved types: [{name:, type:, nullable:}], type being
      # a type Symbol, a Serializer class, or [Serializer]/[:type] for lists.
      def resolved_attributes
        @resolved_attributes ||= attributes_list.values.map do |attr|
          type, nullable = infer(attr)
          { name: attr.name, type: type, nullable: attr.nullable.nil? ? nullable : attr.nullable }
        end.freeze
      end

      def serialize(object, context = {})
        object.nil? ? nil : new(object, context).to_h
      end

      def many(objects, context = {})
        objects = objects.all if objects.respond_to?(:all) && !objects.is_a?(Array) # Sequel datasets
        objects.map { |object| new(object, context).to_h }
      end

      # Defaults for convention-based lookup: ProductSerializer for Product.
      def for(object_class)
        return nil unless object_class.name

        name = "#{object_class.name}Serializer"
        Object.const_defined?(name) ? Object.const_get(name) : nil
      rescue NameError
        nil
      end

      private

      # Explicit types are non-null unless declared nullable or the model's
      # field allows null; inferred types follow the model's field.
      def infer(attr)
        field = model&.gemstack_fields&.[](attr.name)
        return [attr.type, field ? field.options[:null] != false : false] if attr.type
        return [field.type, field.options[:null] != false] if field

        CONVENTIONAL_TYPES.fetch(attr.name) { [:json, true] }
      end
    end

    attr_reader :object, :context

    def initialize(object, context = {})
      @object = object
      @context = context
    end

    def to_h
      self.class.resolved_attributes.each_with_object({}) do |attr, hash|
        definition = self.class.attributes_list[attr[:name]]
        value = definition.block ? instance_exec(object, &definition.block) : object.public_send(attr[:name])
        hash[attr[:name]] = dump(attr[:type], value)
      end
    end
    alias as_json to_h

    private

    def dump(type, value)
      return nil if value.nil?

      case type
      when Symbol then dump_scalar(Types.fetch(type), value)
      when Array
        item = type.first
        value.map { |v| dump(item, v) }
      else type.serialize(value, context) # nested serializer
      end
    end

    # Coerce-then-dump for string types so symbols etc. become strings.
    def dump_scalar(type, value)
      value = type.coerce(value) if %i[string text].include?(type.name) && !value.is_a?(String)
      type.dump(value)
    end
  end
end
