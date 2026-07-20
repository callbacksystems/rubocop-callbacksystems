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
    if check.offense?
      add_offense(node, message: format(MESSAGE, method: node.method_name)) do |corrector|
        corrector.insert_before(line_start_range_for(check.leading_node), "\n")
      end
    end
  end

  alias on_defs on_def

  private
    def describing_macros
      cop_config["DescribingMacros"].to_a.map(&:to_sym)
    end

    def line_start_range_for(node)
      line_start = node.source_range.begin_pos - node.source_range.column
      node.source_range.with(begin_pos: line_start, end_pos: line_start)
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

      # A macro describing the method below it belongs to that method, so the
      # empty line goes above the macro instead of between the two.
      def leading_node
        @leading_node ||= walk_up(node)
      end

      private
        attr_reader :node, :describing_macros

        def previous_node
          @previous_node ||= sibling_above(leading_node)
        end

        def sibling_above(statement)
          statement.left_sibling if statement.parent&.begin_type?
        end

        def walk_up(statement)
          above = sibling_above(statement)
          describing?(above) && glued?(above, statement) ? walk_up(above) : statement
        end

        def describing?(statement)
          bare_send?(statement) && describing_macros.include?(statement.method_name)
        end

        def glued?(above, statement)
          (statement.first_line - above.last_line) <= 1
        end

        def first_in_body?
          ParentCheck.new(leading_node, leading_node.parent).first_in_body?
        end

        def after_visibility_modifier?
          !visibility_modifier_of(previous_node).nil?
        end

        def missing_empty_line?
          glued?(previous_node, leading_node)
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
