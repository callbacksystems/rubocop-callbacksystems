# A method asked which of its parameters its own recursion moves down the parameter list. `walk(child, node)` inside
# `def walk(node, parent)` hands `node` on as the next `parent`, so it is a different value at every step and cannot be
# the shared state of a class. The derived value need not be written inline for this to hold, which is what looking at
# one call in isolation misses.
class RuboCop::Callbacksystems::MethodRecursion
  def initialize(method_node)
    @method_node = method_node
  end

  def shifted_names
    self_calls.flat_map { shifted_names_in(it) }
  end

  private
    attr_reader :method_node

    def self_calls
      method_node.each_node(:send).select { self_call?(it) }
    end

    def self_call?(call)
      call.method?(method_node.method_name) && own_receiver?(call)
    end

    def own_receiver?(call)
      call.receiver.nil? || call.receiver.self_type?
    end

    def shifted_names_in(call)
      call.arguments.each_with_index.filter_map { |argument, index| shifted_name_of(argument, index) }
    end

    def shifted_name_of(argument, index)
      name = local_variable_name_of(argument)
      name if name && lands_elsewhere?(name, index)
    end

    def local_variable_name_of(argument)
      argument.children.first.to_s if argument&.lvar_type?
    end

    def lands_elsewhere?(name, index)
      slots.include?(name) && slots[index] != name
    end

    # Only a required positional parameter has a slot to move between.
    def slots
      @slots ||= method_node.arguments.map { it.name.to_s if it.arg_type? }
    end
end
