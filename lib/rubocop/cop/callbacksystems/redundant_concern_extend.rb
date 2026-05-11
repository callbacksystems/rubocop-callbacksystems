# Detects unnecessary extend ActiveSupport::Concern.
#
# If a module extends ActiveSupport::Concern but doesn't use any of its
# features (included, class_methods, prepended blocks), the extend is
# redundant and adds unnecessary complexity.
#
# @example
#   # bad - extend without using concern features
#   module Searchable
#     extend ActiveSupport::Concern
#
#     def search
#       # ...
#     end
#   end
#
#   # good - using included block
#   module Searchable
#     extend ActiveSupport::Concern
#
#     included do
#       scope :search, -> { ... }
#     end
#   end
#
#   # good - using class_methods
#   module Searchable
#     extend ActiveSupport::Concern
#
#     class_methods do
#       def search(query)
#         # ...
#       end
#     end
#   end
#
#   # good - no extend needed for simple module
#   module Searchable
#     def search
#       # ...
#     end
#   end
#
class RuboCop::Cop::Callbacksystems::RedundantConcernExtend < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  CONCERN_METHODS = %i[included class_methods prepended].freeze
  MESSAGE = "Unnecessary `extend ActiveSupport::Concern`. " \
    "Remove it or use `included`, `class_methods`, or `prepended` blocks."

  def on_module(node)
    concern = ConcernModule.new(node)
    extend_node = concern.find_concern_extend
    add_offense(extend_node, message: MESSAGE) { it.remove(line_removal_range(extend_node)) } if extend_node && !concern.uses_concern_features?
  end

  private
    class ConcernModule
      attr_reader :node

      def initialize(node)
        @node = node
      end

      def find_concern_extend
        return unless node.body

        body = node.body.begin_type? ? node.body.children : [ node.body ]
        body.find { concern_extend?(it) }
      end

      def uses_concern_features?
        return false unless node.body

        node.body.each_descendant(:any_block).any? do |block|
          send_node = block.send_node
          send_node.receiver.nil? && CONCERN_METHODS.include?(send_node.method_name)
        end
      end

      private
        def concern_extend?(target_node)
          target_node.send_type? && target_node.method?(:extend) &&
            target_node.arguments.any? { it.const_type? && [ "ActiveSupport::Concern", "Concern" ].include?(it.source) }
        end
    end
end
