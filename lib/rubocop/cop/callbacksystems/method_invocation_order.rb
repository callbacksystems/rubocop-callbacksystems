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
class RuboCop::Cop::Callbacksystems::MethodInvocationOrder < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Method `%<callee>s` should be defined after `%<caller>s` which calls it."

  def on_class(node)
    return unless node.body

    methods = direct_method_nodes(node.body)
    report_order_violations(node.body, methods) if methods.size >= 2
  end

  alias on_module on_class

  private
    def report_order_violations(body, methods)
      positions = methods.each_with_index.to_h { |method, index| [ method.method_name, index ] }
      visibilities = methods.to_h { [ it.method_name, method_visibility(it) ] }
      macro_referenced = RuboCop::Callbacksystems::MacroReferencedMethods.new(body).collect

      order_violations(methods, positions, visibilities, macro_referenced).each do |callee_name, caller_name|
        add_offense(methods[positions[callee_name]], message: format(MESSAGE, callee: callee_name, caller: caller_name))
      end
    end

    def order_violations(methods, positions, visibilities, macro_referenced)
      build_call_graph(methods, positions).flat_map do |caller_name, callees|
        callees
          .reject { macro_referenced.include?(it) || !out_of_order?(it, caller_name, positions) || private_calling_public?(caller_name, it, visibilities) }
          .map { [ it, caller_name ] }
      end
    end

    def out_of_order?(callee_name, caller_name, positions)
      positions[callee_name] && positions[callee_name] < positions[caller_name]
    end

    def private_calling_public?(caller_name, callee_name, visibilities)
      visibilities[caller_name] == :private && visibilities[callee_name] == :public
    end

    def build_call_graph(methods, positions)
      methods.to_h { [ it.method_name, find_method_calls(it, Set.new(positions.keys)) ] }
    end

    def find_method_calls(method, known_methods_set)
      return [] unless method.body

      method.body.each_node(:send)
        .filter_map { it.method_name if it.receiver.nil? && known_methods_set.include?(it.method_name) }
        .uniq
    end
end
