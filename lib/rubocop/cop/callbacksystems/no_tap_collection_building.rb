# Detects using tap to build collections imperatively. Use declarative methods like map, select, index_by instead.
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
class RuboCop::Cop::Callbacksystems::NoTapCollectionBuilding < RuboCop::Cop::Callbacksystems::Base
  MUTATION_METHODS = %i[<< push append []= store merge!].freeze
  COLLECTION_CLASSES = %i[Set Hash Array].freeze
  MESSAGE = "Don't use `tap` to build collections. Use `map`, `select`, `index_by`, `group_by`, or `to_h` instead."

  def on_block(node)
    add_offense(node, message: MESSAGE) if TapBlock.new(node).offense?
  end

  alias on_numblock on_block
  alias on_itblock on_block

  private
    class TapBlock
      def initialize(node)
        @node = node
      end

      def offense?
        tap_on_empty_collection? && mutation_in_block?
      end

      private
        attr_reader :node

        def tap_on_empty_collection?
          node.method?(:tap) && CollectionReceiver.new(node.receiver).empty_collection?
        end

        def mutation_in_block?
          node.body&.each_node(:send)&.any? { MUTATION_METHODS.include?(it.method_name) }
        end
    end

    class CollectionReceiver
      include RuboCop::Callbacksystems::Helpers

      def initialize(receiver)
        @receiver = receiver
      end

      def empty_collection?
        receiver && (literal_empty_collection? || collection_class_constructor?)
      end

      private
        attr_reader :receiver

        def literal_empty_collection?
          receiver.type?(:array, :hash) && receiver.children.empty?
        end

        def collection_class_constructor?
          constructor = constructor_send
          constructor&.method?(:new) &&
            constructor.receiver&.const_type? &&
            COLLECTION_CLASSES.include?(constructor.receiver.short_name)
        end

        def constructor_send
          return receiver if receiver.send_type?

          receiver.send_node if any_block_type?(receiver)
        end
    end
end
