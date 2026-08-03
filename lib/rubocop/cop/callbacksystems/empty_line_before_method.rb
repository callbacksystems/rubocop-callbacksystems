# Enforces an empty line before method definitions.
#
# @example
#   # bad - macro directly before method
#   before_action :authenticate
#   def index
#   end
#
#   # bad - consecutive methods without empty line
#   def name
#   end
#   def email
#   end
#
#   # good - empty line before method
#   before_action :authenticate
#
#   def index
#   end
#
#   # good - empty line between methods
#   def name
#   end
#
#   def email
#   end
#
#   # good - consecutive macros are fine
#   validates :name
#   validates :email
#
#   # good - first method in class body needs no preceding empty line
#   class User
#     def name
#     end
#   end
#
#   # good - method after visibility modifier needs no empty line
#   private
#     def helper
#     end
#
class RuboCop::Cop::Callbacksystems::EmptyLineBeforeMethod < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = "Add an empty line before `%<method>s`."

  def on_def(node)
    check = SiblingCheck.new(node, describing_macros)
    add_offense(node, message: format(MESSAGE, method: node.method_name)) { check.separate(it) } if check.offense?
  end

  alias on_defs on_def

  private
    def describing_macros
      Array(cop_config["DescribingMacros"]).map(&:to_sym)
    end

    class SiblingCheck
      include RuboCop::Callbacksystems::Helpers

      def initialize(node, describing_macros)
        @node = node
        @describing_macros = describing_macros
      end

      def offense?
        previous_node && !first_in_body? && !after_visibility_modifier? && missing_empty_line?
      end

      def separate(corrector)
        corrector.insert_before(line_start_of(leading_node), "\n")
      end

      private
        attr_reader :node, :describing_macros

        def previous_node
          @previous_node ||= sibling_above(leading_node)
        end

        def sibling_above(statement)
          statement.left_sibling if statement.parent&.begin_type?
        end

        # A macro describing the method below belongs to it, so the blank line goes
        # above the macro.
        def leading_node
          @leading_node ||= topmost_of(node)
        end

        def topmost_of(statement)
          above = sibling_above(statement)
          describing?(above) && adjacent?(above, statement) ? topmost_of(above) : statement
        end

        def describing?(statement)
          bare_send?(statement) && describing_macros.include?(statement.method_name)
        end

        def adjacent?(above, statement)
          (statement.first_line - above.last_line) <= 1
        end

        def first_in_body?
          ParentCheck.new(leading_node, leading_node.parent).first_in_body?
        end

        def after_visibility_modifier?
          !visibility_modifier_of(previous_node).nil?
        end

        def missing_empty_line?
          adjacent?(previous_node, leading_node)
        end

        def line_start_of(statement)
          range = statement.source_range
          range.with(begin_pos: range.begin_pos - range.column, end_pos: range.begin_pos - range.column)
        end
    end

    class ParentCheck
      def initialize(node, parent)
        @node = node
        @parent = parent
      end

      def first_in_body?
        if parent
          case parent.type
          when :begin
            first_in_begin?
          when :class, :module, :sclass
            parent.body == node
          else
            false
          end
        else
          true
        end
      end

      private
        attr_reader :node, :parent

        def first_in_begin?
          parent.children.first == node &&
            (parent.parent.nil? || parent.parent.type?(:block, :class, :module))
        end
    end
end
