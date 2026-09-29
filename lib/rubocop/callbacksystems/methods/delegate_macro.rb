class RuboCop::Callbacksystems::Methods::DelegateMacro
  include RuboCop::Callbacksystems::Helpers

  MISSING_DELEGATE_METHODS = %i[ method_missing respond_to_missing? ]

  def initialize(node)
    @node = node
  end

  def macro?
    delegate_macro?(node) && !options.nil?
  end

  def target
    value_of(:to)&.then { name_of(it) }
  end

  # The methods read on the delegation target, before a prefix changes the methods this macro defines.
  def target_method_names
    literal_method_names if node.method?(:delegate)
  end

  # Nothing is returned when a dynamic argument or option leaves the names unknowable without executing the file.
  def defined_method_names
    if node.method?(:delegate_missing_to)
      MISSING_DELEGATE_METHODS
    elsif node.method?(:delegate)
      prefixed_method_names
    end
  end

  def private?
    visibility == :private
  end

  def plain?(private:)
    visibility == (private ? :private : :public) && inactive_option?(:prefix) && inactive_option?(:allow_nil)
  end

  def private_option_known?
    options && option_known?(:private)
  end

  def private_option
    option_for(:private)
  end

  def first_option
    keyword_options.elements.first || options
  end

  def last_option
    keyword_options.elements.last || options
  end

  private
    attr_reader :node

    def options
      node.last_argument if node.last_argument&.hash_type?
    end

    def value_of(key)
      option_for(key)&.value
    end

    def option_for(key)
      keyword_options.option_for(key) if options
    end

    def keyword_options
      @keyword_options ||= RuboCop::Callbacksystems::Hashes::KeywordOptions.new(options)
    end

    def name_of(value)
      literal_name_of(value) if value.type?(:sym, :str, :const)
    end

    def literal_method_names
      method_arguments.filter_map { literal_method_name_of(it) }.then do |names|
        names if names.size == method_arguments.size
      end
    end

    def method_arguments
      @method_arguments ||= node.arguments.reject { it.equal?(options) }
    end

    def literal_method_name_of(argument)
      argument.value.to_sym if argument.type?(:sym, :str)
    end

    def prefixed_method_names
      if target_method_names && option_known?(:prefix)
        prefix = prefix_name

        if prefix || !prefix_active?
          target_method_names.map { prefix ? :"#{prefix}_#{it}" : it }
        end
      end
    end

    def option_known?(key)
      options.nil? || keyword_options.known?(key)
    end

    def prefix_name
      value = value_of(:prefix)

      if value&.true_type?
        target if target&.match?(/\A[a-z_]/)
      elsif value&.type?(:sym, :str)
        value.value.to_s
      end
    end

    def prefix_active?
      value = value_of(:prefix)

      value && !value.falsey_literal?
    end

    def visibility
      if private_option
        literal_visibility
      elsif options && keyword_options.known?(:private)
        :public
      end
    end

    def literal_visibility
      if private_option.value.true_type?
        :private
      elsif private_option.value.falsey_literal?
        :public
      end
    end

    def inactive_option?(key)
      option = option_for(key)

      option ? option.value.falsey_literal? : options && keyword_options.known?(key)
    end
end
