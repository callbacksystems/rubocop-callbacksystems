class RuboCop::Callbacksystems::MacroReferencedMethods
  include RuboCop::Callbacksystems::Helpers

  CALLBACK_OPTIONS = %i[if unless].freeze

  def initialize(body)
    @body = body
    @results = Set.new
  end

  def collect
    traverse(body)
    results
  end

  private
    attr_reader :body, :results

    def traverse(node)
      return unless node

      collect_from_node(node)
      node.children.each { traverse(it) if it.is_a?(RuboCop::AST::Node) }
    end

    def collect_from_node(node)
      collect_from_send(node) if node.send_type?
      collect_from_block(node) if any_block_type?(node)
    end

    def collect_from_send(node)
      collect_symbol_arguments(node)
      collect_lambda_arguments(node)
      collect_hash_options(node)
    end

    def collect_symbol_arguments(node)
      sym_arg = node.arguments.find(&:sym_type?)
      results << sym_arg.value if sym_arg
    end

    def collect_lambda_arguments(node)
      node.arguments.select(&:block_type?).each do |block_arg|
        collect_method_calls_from(block_arg.body)
      end
    end

    def collect_hash_options(node)
      node.arguments.select(&:hash_type?).each do |hash_arg|
        hash_arg.each_pair { |key, value| collect_from_option(key, value) }
      end
    end

    def collect_from_option(key, value)
      return unless key.sym_type?

      case key.value
      when :to
        collect_delegate_target(value)
      when *CALLBACK_OPTIONS
        collect_callback_condition(value)
      end
    end

    def collect_delegate_target(value)
      case value.type
      when :sym
        results << value.value
      when :str
        # delegate to: "foo.bar" — extract "foo"
        results << value.value.to_s.split(".").first&.to_sym
      end
    end

    def collect_callback_condition(value)
      case value.type
      when :sym
        results << value.value
      when :block
        collect_method_calls_from(value.body)
      end
    end

    def collect_from_block(node)
      collect_method_calls_from(node.body)
    end

    def collect_method_calls_from(body)
      body&.each_node(:send) { results << it.method_name if it.receiver.nil? }
    end
end
