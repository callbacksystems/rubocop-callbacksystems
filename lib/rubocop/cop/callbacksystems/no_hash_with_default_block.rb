# Detects `Hash.new` with a default block that initializes missing keys to an empty collection. The pattern reaches for
# an imperative accumulator when the declarative equivalent (`group_by`, `group_by + transform_values`) is almost always
# clearer.
#
# `NoTapCollectionBuilding` only catches the `.tap { ... }` flavour of this pattern; this cop also catches it when used
# standalone, passed to `each_with_object`, assigned to a variable, etc.
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

  # @!method hash_new_block?(node)
  def_node_matcher :hash_new_block?, <<~PATTERN
    (block
      (send (const _ :Hash) :new)
      (args (arg $_) (arg $_))
      $_body)
  PATTERN

  # @!method assigns_empty_collection_to_key?(body, hash_name, key_name)
  def_node_matcher :assigns_empty_collection_to_key?, <<~PATTERN
    (send (lvar %1) :[]= (lvar %2) {
      (array)
      (hash)
      (send (const _ {:Set :Hash :Array}) :new)
    })
  PATTERN

  def on_block(node)
    hash_name, key_name, body = hash_new_block?(node)

    add_offense(node, message: MESSAGE) if hash_name && assigns_empty_collection_to_key?(body, hash_name, key_name)
  end

  alias on_numblock on_block
  alias on_itblock on_block
end
