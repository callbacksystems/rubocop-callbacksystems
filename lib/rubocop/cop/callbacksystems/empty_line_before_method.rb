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
    if SiblingCheck.new(node).offense?
      add_offense(node, message: format(MESSAGE, method: node.method_name)) do |corrector|
        corrector.insert_before(line_start_range_for(node), "\n")
      end
    end
  end

  alias on_defs on_def

  private
    def line_start_range_for(node)
      line_start = node.source_range.begin_pos - node.source_range.column
      node.source_range.with(begin_pos: line_start, end_pos: line_start)
    end

    class SiblingCheck
      include RuboCop::Callbacksystems::Helpers

      def initialize(node)
        @node = node
      end

      def offense?
        previous_node && !first_in_body? && !after_visibility_modifier? && missing_empty_line?
      end

      private
        attr_reader :node

        def previous_node
          @previous_node ||= node.left_sibling if node.parent&.begin_type?
        end

        def first_in_body?
          ParentCheck.new(node, node.parent).first_in_body?
        end

        def after_visibility_modifier?
          !visibility_modifier_of(previous_node).nil?
        end

        def missing_empty_line?
          (node.first_line - previous_node.last_line) <= 1
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
