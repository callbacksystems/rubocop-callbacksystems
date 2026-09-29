# Detects using tap to build collections imperatively. A `tap` on an empty
# collection is a loop that fills it by hand, so a reader has to run the block
# to learn what comes out, where `map`, `select`, `index_by` or `group_by`
# names the result in the call itself.
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
  def on_block(node)
    report TapBlock.new(node)
  end

  alias on_numblock on_block
  alias on_itblock on_block

  private
    class TapBlock
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Don't use `tap` to build collections. Use `map`, `select`, `index_by`, `group_by`, or `to_h` instead."
      MUTATION_METHODS = %i[ << push append []= store merge! ]

      def initialize(node)
        @node = node
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(node, MESSAGE) if tap_on_empty_collection? && mutation_in_block?
      end

      private
        attr_reader :node

        def tap_on_empty_collection?
          node.method?(:tap) && CollectionReceiver.new(node.receiver).empty_collection?
        end

        def mutation_in_block?
          RuboCop::Callbacksystems::Execution::Immediate.new(node.body).any? do |candidate|
            candidate.call_type? && mutates_collection?(candidate)
          end
        end

        def mutates_collection?(call)
          MUTATION_METHODS.include?(call.method_name) && yielded_collection?(call.receiver)
        end

        def yielded_collection?(receiver)
          directly_yielded_collection?(receiver) || stored_default_collection?(receiver)
        end

        def directly_yielded_collection?(receiver)
          receiver&.lvar_type? && node.argument_list.any? { it.name == receiver.name } &&
            !name_rebound_between?(receiver.name, node: receiver, boundary: node)
        end

        def stored_default_collection?(receiver)
          receiver&.call_type? && receiver.method?(:[]) && directly_yielded_collection?(receiver.receiver) &&
            StoredHashDefault.new(node.receiver).collection?
        end
    end

    class StoredHashDefault
      def initialize(block)
        @block = block
      end

      def collection?
        default_block? && stores_default? &&
          CollectionReceiver.new(default_value).empty_collection?
      end

      private
        attr_reader :block

        def default_block?
          block&.any_block_type? && argument_names.size == 2 && block.argument_list.all?(&:arg_type?)
        end

        def argument_names
          @argument_names ||= block.argument_list.map(&:name)
        end

        def stores_default?
          hash_argument_assigned? && key_argument_used?
        end

        def hash_argument_assigned?
          assignment&.call_type? && assignment.method?(:[]=) && assignment.receiver&.lvar_type? &&
            assignment.receiver.name == argument_names.first
        end

        def assignment
          block.body
        end

        def key_argument_used?
          key&.lvar_type? && key.name == argument_names.second
        end

        def key
          assignment.first_argument
        end

        def default_value
          assignment.last_argument
        end
    end

    class CollectionReceiver
      include RuboCop::Callbacksystems::Helpers

      COLLECTION_CLASSES = %i[ Set Hash Array ]

      def initialize(receiver)
        @receiver = receiver
      end

      def empty_collection?
        receiver && (empty_collection_literal?(receiver) || collection_class_constructor?)
      end

      private
        attr_reader :receiver

        def collection_class_constructor?
          constructor.send_type? && collection_constructor? &&
            constructor_without_entries?
        end

        def constructor
          @constructor ||= call_of(receiver)
        end

        def collection_constructor?
          constructor.method?(:new) && core_constant?(constructor.receiver) &&
            COLLECTION_CLASSES.include?(constructor.receiver.short_name)
        end

        def constructor_without_entries?
          constructor.arguments.empty? || constructor.receiver.short_name == :Hash
        end
    end
end
