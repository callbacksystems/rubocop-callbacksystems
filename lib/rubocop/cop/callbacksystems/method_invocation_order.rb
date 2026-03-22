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
      macro_referenced = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).collect

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
