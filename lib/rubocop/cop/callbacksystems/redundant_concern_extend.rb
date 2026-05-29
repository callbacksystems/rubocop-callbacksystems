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

  CONCERN_CONSTANTS = %w[ActiveSupport::Concern Concern].freeze
  CONCERN_METHODS = %i[included class_methods prepended].freeze
  MESSAGE = "Unnecessary `extend ActiveSupport::Concern`. " \
    "Remove it or use `included`, `class_methods`, or `prepended` blocks."

  def on_module(node)
    concern = ConcernModule.new(node)
    add_offense(concern.offense_node, message: MESSAGE) { it.remove(line_removal_range_for(concern.offense_node)) } if concern.offense?
  end

  private
    class ConcernModule
      include RuboCop::Callbacksystems::Helpers

      def initialize(node)
        @node = node
      end

      def offense?
        offense_node && !uses_concern_features?
      end

      def offense_node
        @offense_node ||= statements_in(node.body).find { concern_extend?(it) }
      end

      private
        attr_reader :node

        def concern_extend?(target_node)
          target_node.send_type? && target_node.method?(:extend) &&
            target_node.arguments.any? { it.const_type? && CONCERN_CONSTANTS.include?(it.source) }
        end

        def uses_concern_features?
          node.body&.each_descendant(:any_block)&.any? do |block|
            bare_send?(block.send_node) && CONCERN_METHODS.include?(block.method_name)
          end || false
        end
    end
end
