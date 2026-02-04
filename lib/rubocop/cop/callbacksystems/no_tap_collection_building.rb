# Detects using tap to build collections imperatively.
# Use declarative methods like map, select, index_by instead.
#
# @example
#   # bad - building array with tap
#   [].tap { |arr| items.each { |i| arr << i.name } }
#
#   # good - use map
#   items.map { it.name }
#
#   # bad - building hash with tap
#   {}.tap { |h| items.each { |i| h[i.id] = i } }
#
#   # good - use index_by or to_h
#   items.index_by { it.id }
#
#   # bad - building Set with tap
#   Set.new.tap { |s| items.each { |i| s << i.id } }
#
#   # good - use Set.new with block or to_set
#   items.map(&:id).to_set
#
#   # bad - building Hash with default value and tap
#   Hash.new { |h, k| h[k] = [] }.tap { |h| items.each { |i| h[i.type] << i } }
#
#   # good - use group_by
#   items.group_by(&:type)
#
#   # ok - tap for logging (not collection building)
#   user.tap { |u| logger.info(u.id) }
#
#   # ok - tap for configuring object
#   User.new.tap { |u| u.name = "John" }
#
class RuboCop::Cop::Callbacksystems::NoTapCollectionBuilding < RuboCop::Cop::Base
  MUTATION_METHODS = %i[<< push append []= store merge!].freeze
  COLLECTION_CLASSES = %i[Set Hash Array].freeze
  MESSAGE = "Don't use `tap` to build collections. Use `map`, `select`, `index_by`, `group_by`, or `to_h` instead."

  def on_block(node)
    add_offense(node, message: MESSAGE) if TapBlock.new(node).offense?
  end

  alias on_numblock on_block

  private
    class TapBlock
      def initialize(node)
        @node = node
      end

      def offense?
        tap_on_empty_collection? && has_mutation_in_block?
      end

      private
        attr_reader :node

        def tap_on_empty_collection?
          node.method?(:tap) && CollectionReceiver.new(node.send_node.receiver).empty_collection?
        end

        def has_mutation_in_block?
          node.body&.each_node(:send)&.any? { |send_node| MUTATION_METHODS.include?(send_node.method_name) }
        end
    end

    class CollectionReceiver
      def initialize(receiver)
        @receiver = receiver
      end

      def empty_collection?
        return false unless receiver

        literal_empty_collection? || class_new_call? || block_with_class_new?
      end

      private
        attr_reader :receiver

        def literal_empty_collection?
          (receiver.array_type? || receiver.hash_type?) && receiver.children.empty?
        end

        def class_new_call?
          return false unless receiver.send_type? && receiver.method_name == :new

          receiver.receiver&.const_type? && COLLECTION_CLASSES.include?(receiver.receiver.short_name)
        end

        def block_with_class_new?
          return false unless receiver.block_type?

          receiver.send_node.method_name == :new &&
            receiver.send_node.receiver&.const_type? &&
            COLLECTION_CLASSES.include?(receiver.send_node.receiver.short_name)
        end
    end
end
