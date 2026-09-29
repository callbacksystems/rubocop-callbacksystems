# Detects `Hash.new` with a default block that initializes missing keys to an
# empty collection. The pattern reaches for an imperative accumulator when the
# declarative equivalent (`group_by`, `group_by + transform_values`) is almost
# always clearer.
#
# `NoTapCollectionBuilding` only catches the `.tap { ... }` flavor of this
# pattern; this cop also catches it when used standalone, passed to
# `each_with_object`, assigned to a variable, etc.
#
# @example
#   # bad - building a hash of groups imperatively
#   groups = Hash.new { |h, k| h[k] = [] }
#   items.each { |i| groups[i.type] << i }
#
#   # bad - same with each_with_object
#   items.each_with_object(Hash.new { |h, k| h[k] = [] }) do |item, groups|
#     groups[item.type] << item
#   end
#
#   # bad - hash of sets
#   tags = Hash.new { |h, k| h[k] = Set.new }
#
#   # good - use group_by
#   items.group_by(&:type)
#
#   # good - group_by + transform_values when the values need more shaping
#   items.group_by(&:type).transform_values { Set.new(it.map(&:tag)) }
#
class RuboCop::Cop::Callbacksystems::NoHashWithDefaultBlock < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Avoid `Hash.new { |h, k| h[k] = ... }`. Use `group_by` (or `group_by + transform_values`) instead."

  # @!method value_assigned_to_key(body, hash_name, key_name)
  def_node_matcher :value_assigned_to_key, <<~PATTERN
    (send (lvar %1) :[]= (lvar %2) $_)
  PATTERN

  def on_block(node)
    if hash_new_block?(node) && core_collection_constructor?(node.send_node, :Hash)
      hash_name, key_name = node.argument_list.map(&:name)
      if empty_collection?(value_assigned_to_key(node.body, hash_name, key_name))
        add_offense(node, message: MESSAGE)
      end
    end
  end

  alias on_numblock on_block
  alias on_itblock on_block

  private
    def hash_new_block?(node)
      call = node.send_node
      call.send_type? && call.method?(:new) && node.argument_list.size == 2 &&
        node.argument_list.all?(&:arg_type?)
    end

    def core_collection_constructor?(node, *receivers)
      node&.send_type? && node.method?(:new) && core_constant?(node.receiver) &&
        receivers.include?(node.receiver.short_name)
    end

    def empty_collection?(node)
      empty_collection_literal?(node) || collection_constructor?(node)
    end

    def collection_constructor?(node)
      node&.send_type? && node.arguments.empty? && core_collection_constructor?(node, :Array, :Hash, :Set)
    end
end
