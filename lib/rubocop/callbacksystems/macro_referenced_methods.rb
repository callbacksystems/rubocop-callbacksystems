# Collects method names referenced in macros (callbacks, delegates, blocks).
# Handles: symbol arguments, lambda arguments, if:/unless: options, delegate to:, and blocks.
#
# @example
#   MacroReferencedMethods.new(class_node.body).collect  # => Set[:validate, :process, ...]
#
class RuboCop::Callbacksystems::MacroReferencedMethods
  CALLBACK_OPTIONS = %i[if unless].freeze
  BLOCK_TYPES = %i[block numblock].freeze

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
      node.children.each { |child| traverse(child) if child.is_a?(RuboCop::AST::Node) }
    end

    def collect_from_node(node)
      collect_from_send(node) if node.send_type?
      collect_from_block(node) if BLOCK_TYPES.include?(node.type)
    end

    def collect_from_send(node)
      collect_symbol_arguments(node)
      collect_lambda_arguments(node)
      collect_hash_options(node)
    end

    def collect_symbol_arguments(node)
      results << node.arguments.find(&:sym_type?)&.value
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
        # Handle "a.b.c" - extract first method in chain
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
      body&.each_node(:send) { |s| results << s.method_name if s.receiver.nil? }
    end
end
