# Mixins come before anything else in a class or module body, constants
# included. What a class is made of reads first, then what it holds.
#
# `Layout/ClassStructure` only orders the categories listed in its
# `ExpectedOrder`, and adding constants there would also forbid declaring them
# in the private section, so the rule lives here instead.
#
# @example
#   # bad - the constant comes first
#   class Configuration
#     HOOKS = [ :before, :after ].freeze
#
#     include Validation
#   end
#
#   # good
#   class Configuration
#     include Validation
#
#     HOOKS = [ :before, :after ].freeze
#   end
#
class RuboCop::Cop::Callbacksystems::MixinsFirst < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  MIXIN_MACROS = %i[include extend prepend].freeze
  MESSAGE = "Move this `%<mixin>s` to the top of the body; mixins come before anything else."

  def on_class(node)
    body = ClassBody.new(node)
    body.misplaced_mixins.each do |mixin|
      add_offense(mixin, message: format(MESSAGE, mixin: mixin.method_name)) { body.move_to_top(it, mixin) }
    end
  end

  alias on_module on_class

  private
    class ClassBody
      include RuboCop::Callbacksystems::Helpers

      def initialize(node)
        @node = node
      end

      def misplaced_mixins
        statements.drop_while { mixin?(it) }.select { movable_mixin?(it) }
      end

      def move_to_top(corrector, mixin)
        corrector.insert_before(statements.first, "#{mixin.source}\n#{indentation_of(statements.first)}")
        corrector.remove(statement_removal_range_for(mixin))
      end

      private
        attr_reader :node

        def statements
          @statements ||= statements_in(node.body)
        end

        def mixin?(statement)
          bare_send?(statement) && MIXIN_MACROS.include?(statement.method_name)
        end

        def movable_mixin?(statement)
          mixin?(statement) && MixinArguments.new(statement, statements).independent?
        end
    end

    # A mixin reading a constant declared above it cannot move over that
    # declaration, so its placement is not the author's choice.
    class MixinArguments
      include RuboCop::Callbacksystems::Helpers

      def initialize(node, siblings)
        @node = node
        @siblings = siblings
      end

      def independent?
        !constant_names.intersect?(constant_names_declared_before)
      end

      private
        attr_reader :node, :siblings

        def constant_names
          node.arguments.flat_map { it.each_node(:const).map(&:short_name) }
        end

        def constant_names_declared_before
          siblings.take_while { it != node }.select(&:casgn_type?).map(&:name)
        end
    end
end
