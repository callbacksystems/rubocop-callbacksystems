# Do not use explicit `public` modifier. Public methods should be at the beginning
# of the class/module, before any `private` or `protected` sections.
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

  MESSAGE = "Do not use `public` modifier. Public methods should be defined at the beginning of the class."

  def on_send(node)
    modifier = PublicModifier.new(node)
    add_offense(node, message: MESSAGE) { modifier.correct(it) } if modifier.offense?
  end

  alias on_csend on_send

  private
    class PublicModifier
      include RuboCop::Callbacksystems::Helpers

      def initialize(node)
        @node = node
      end

      def offense?
        bare_send?(node) && node.method?(:public) && !inside_nested_class?
      end

      # Removing `public` is only safe when nothing turned the class private first.
      # A bare `public` reopening visibility after `private` would make the methods
      # below it private, so that case is reported but left for a human to reorder.
      def correct(corrector)
        corrector.remove(line_removal_range_for(node)) if redundant?
      end

      private
        attr_reader :node

        def inside_nested_class?
          node.each_ancestor(:class, :module).drop(1).any?
        end

        def redundant?
          preceding_siblings.none? { %i[private protected].include?(visibility_modifier_of(it)) }
        end

        def preceding_siblings
          (node.parent&.children || []).take_while { it != node }
        end
    end
end
