# Detects an `extend ActiveSupport::Concern` the module never uses. The extend
# promises `included`, `class_methods` or `prepended` hooks, or concern
# dependencies declared with `include` or `prepend`, so a reader goes looking
# for them. A module with none is a plain mixin carrying a promise it never
# keeps.
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

  def on_module(node)
    report ConcernModule.new(node, source_comments:)
  end

  private
    class ConcernModule
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Unnecessary `extend ActiveSupport::Concern`. " \
        "Remove it or use concern hooks or dependencies."
      CONCERN_CONSTANTS = %w[ ActiveSupport::Concern Concern ]
      CONCERN_METHODS = %i[ included class_methods prepended ]
      DEPENDENCY_METHODS = %i[ include prepend ]

      def initialize(node, source_comments:)
        @node = node
        @source_comments = source_comments
      end

      def offense
        if redundant?
          RuboCop::Callbacksystems::Offense.new \
            concern_extend, MESSAGE, correcting: correction_uncommented? do |corrector|
              correct(corrector)
            end
        end
      end

      private
        attr_reader :node, :source_comments

        def redundant?
          concern_extend && !uses_concern_features?
        end

        def concern_extend
          @concern_extend ||= statements_in(node.body).find { concern_extend?(it) }
        end

        def concern_extend?(statement)
          statement.send_type? && statement.method?(:extend) && statement.arguments.any? { concern_constant?(it) }
        end

        def concern_constant?(argument)
          CONCERN_CONSTANTS.include?(constant_name_of(argument)&.delete_prefix("::"))
        end

        def uses_concern_features?
          concern_hooks.any? || concern_dependencies.any? || class_methods_module?
        end

        def concern_hooks
          nodes_in(node.body, :any_block).select do |block|
            bare_send?(block.send_node) && CONCERN_METHODS.include?(block.method_name)
          end
        end

        def concern_dependencies
          nodes_in(node.body, :send).select do |call|
            bare_send?(call) && DEPENDENCY_METHODS.include?(call.method_name) &&
              call.each_ancestor(:def, :defs, :class, :module).first.equal?(node)
          end
        end

        def class_methods_module?
          statements_in(node.body).any? do |statement|
            statement.module_type? && constant_name_of(statement.identifier) == "ClassMethods"
          end
        end

        def correction_uncommented?
          !source_comments.any_within?(correction_range)
        end

        def correction_range
          concern_extend.arguments.one? ? statement_removal_range_for(concern_extend) : concern_argument_removal_range
        end

        def concern_argument_removal_range
          if argument_after_concern
            concern_argument.source_range.with(end_pos: argument_after_concern.source_range.begin_pos)
          else
            argument_before_concern.source_range.end.join(concern_argument.source_range.end)
          end
        end

        def argument_after_concern
          concern_extend.arguments[concern_argument_index + 1]
        end

        def concern_argument_index
          concern_extend.arguments.index(concern_argument)
        end

        def concern_argument
          @concern_argument ||= concern_extend.arguments.find { concern_constant?(it) }
        end

        def argument_before_concern
          concern_extend.arguments[concern_argument_index - 1]
        end

        def correct(corrector)
          if concern_extend.arguments.one?
            corrector.remove(statement_removal_range_for(concern_extend))
          else
            corrector.remove(concern_argument_removal_range)
          end
        end
    end
end
