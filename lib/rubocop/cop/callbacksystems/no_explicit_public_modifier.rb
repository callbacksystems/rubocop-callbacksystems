# Do not use an explicit `public` modifier. A class reads top-down, public
# methods first and a single `private` after them, so a `public` that reopens
# visibility later makes a reader track which section each method sits in
# instead of trusting the order.
#
# @example
#   # bad - using explicit public modifier
#   class Foo
#     private
#       def private_method; end
#
#     public
#       def public_method; end
#   end
#
#   # bad - using public with method name
#   class Foo
#     def some_method; end
#     public :some_method
#   end
#
#   # good - public methods at the beginning
#   class Foo
#     def public_method; end
#
#     private
#       def private_method; end
#   end
#
class RuboCop::Cop::Callbacksystems::NoExplicitPublicModifier < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  def on_send(node)
    report PublicModifier.new(node, source_comments:)
  end

  alias on_csend on_send

  private
    class PublicModifier
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Do not use `public` modifier. Public methods should be defined at the beginning of the class."

      def initialize(node, source_comments:)
        @node = node
        @source_comments = source_comments
      end

      def offense
        if explicit?
          RuboCop::Callbacksystems::Offense.new(node, MESSAGE, correcting: redundant? && uncommented?) { correct(it) }
        end
      end

      private
        attr_reader :node, :source_comments

        def explicit?
          bare_send?(node) && node.method?(:public) && !inside_nested_class?
        end

        def inside_nested_class?
          node.each_ancestor(:class, :module).drop(1).any?
        end

        # A bare `public` after `private` is what keeps the methods below it public, so a human reorders that one.
        def redundant?
          node.arguments.empty? && enclosing_definition_of(node) &&
            statements_before(node).none? { leaves_public_section?(it) }
        end

        def uncommented?
          !source_comments.any_on_lines?(node.first_line..node.last_line)
        end

        def correct(corrector)
          corrector.remove(statement_removal_range_for(node))
        end
    end
end
