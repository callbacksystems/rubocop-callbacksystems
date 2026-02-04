# Ensures methods are ordered by invocation: callers before callees.
# Methods that are called should be defined after the methods that call them.
#
# Methods referenced by macros (callbacks, delegates, etc.) are considered
# to have a caller at the macro position, so they can be defined early.
#
# @example
#   # bad - called method defined before caller
#   def helper
#     # ...
#   end
#
#   def process
#     helper
#   end
#
#   # good - caller defined before callee
#   def process
#     helper
#   end
#
#   def helper
#     # ...
#   end
#
#   # good - with private section
#   def process
#     helper_1
#     helper_2
#   end
#
#   private
#     def helper_1
#       nested_helper
#     end
#
#     def nested_helper
#       # ...
#     end
#
#     def helper_2
#       # ...
#     end
#
#   # good - method referenced by callback can be defined early
#   included do
#     after_commit :notify_later
#   end
#
#   def notify_later
#     NotifyJob.perform_later(self)
#   end
#
#   def process
#     notify_later  # calls notify_later, but it's already pinned by callback
#   end
#
class RuboCop::Cop::Callbacksystems::MethodInvocationOrder < RuboCop::Cop::Base
  BLOCK_TYPES = %i[block numblock].freeze
  MESSAGE = "Method `%<callee>s` should be defined after `%<caller>s` which calls it."

  def on_class(node)
    return unless node.body

    methods = MethodDefinitions.new(node.body).collect
    report_order_violations(node.body, methods) if methods.size >= 2
  end

  alias on_module on_class

  private
    def report_order_violations(body, methods)
      positions = methods.each_with_index.to_h { |method, index| [ method.method_name, index ] }
      macro_referenced = MacroReferences.new(body).collect

      order_violations(methods, positions, macro_referenced).each do |callee_name, caller_name|
        add_offense(methods[positions[callee_name]], message: format(MESSAGE, callee: callee_name, caller: caller_name))
      end
    end

    def order_violations(methods, positions, macro_referenced)
      call_graph = build_call_graph(methods, positions)
      visibilities = method_visibilities(methods)

      call_graph.flat_map do |caller_name, callees|
        callees.filter_map do |callee_name|
          next if macro_referenced.include?(callee_name)
          next unless positions[callee_name] && positions[callee_name] < positions[caller_name]
          next if private_calling_public?(caller_name, callee_name, visibilities)

          [ callee_name, caller_name ]
        end
      end
    end

    def private_calling_public?(caller_name, callee_name, visibilities)
      visibilities[caller_name] == :private && visibilities[callee_name] == :public
    end

    def method_visibilities(methods)
      methods.to_h { |method| [ method.method_name, RuboCop::Callbacksystems::Helpers.method_visibility(method) ] }
    end

    def build_call_graph(methods, positions)
      known_methods_set = Set.new(positions.keys)
      methods.to_h { |method| [ method.method_name, find_method_calls(method, known_methods_set) ] }
    end

    def find_method_calls(method, known_methods_set)
      return [] unless method.body

      method.body.each_node(:send)
        .select { |send_node| send_node.receiver.nil? && known_methods_set.include?(send_node.method_name) }
        .map(&:method_name)
        .uniq
    end

    class MacroReferences
      attr_reader :body, :results

      def initialize(body)
        @body = body
        @results = Set.new
      end

      def collect
        traverse(body)
        results
      end

      private
        def traverse(target_node)
          return unless target_node

          NodeCollector.new(target_node, results).collect
          target_node.children.each { |child| traverse(child) if child.is_a?(RuboCop::AST::Node) }
        end

        class NodeCollector
          CALLBACK_OPTIONS = %i[if unless].freeze
          attr_reader :node, :results

          def initialize(node, results)
            @node = node
            @results = results
          end

          def collect
            collect_from_send if node.send_type?
            collect_from_block if BLOCK_TYPES.include?(node.type)
          end

          private
            def collect_from_send
              collect_symbol_arguments
              collect_lambda_arguments
              collect_hash_options
            end

            def collect_symbol_arguments
              results << node.arguments.find(&:sym_type?)&.value
            end

            def collect_lambda_arguments
              node.arguments.select(&:block_type?).each do |block_arg|
                collect_method_calls_from(block_arg.body)
              end
            end

            def collect_hash_options
              node.arguments.select(&:hash_type?).each do |hash_arg|
                hash_arg.each_pair { |key, value| collect_from_option(key, value) }
              end
            end

            def collect_from_option(key, value)
              return unless key.sym_type?

              case key.value
              when :to
                results << value.value if value.sym_type?
              when *CALLBACK_OPTIONS
                collect_callback_condition(value)
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

            def collect_from_block
              collect_method_calls_from(node.body)
            end

            def collect_method_calls_from(body)
              body&.each_node(:send) { |s| results << s.method_name if s.receiver.nil? }
            end
        end
    end

    class MethodDefinitions
      attr_reader :root, :results

      def initialize(root)
        @root = root
        @results = []
      end

      def collect
        traverse(root)
        results
      end

      private
        def traverse(node)
          return unless node

          case node.type
          when :def, :defs
            results << node
          when :begin, :kwbegin
            node.children.each { |child| traverse(child) }
          when :sclass
            traverse(node.body) if node.body
          end
        end
    end
end
