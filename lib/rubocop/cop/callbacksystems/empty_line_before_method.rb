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
    check_empty_line_before(node)
  end

  alias on_defs on_def

  private
    def check_empty_line_before(node)
      return unless needs_empty_line_before?(node)

      add_offense(node, message: format(MESSAGE, method: node.method_name)) do |corrector|
        line_start = node.source_range.begin_pos - node.source_range.column
        corrector.insert_before(node.source_range.with(begin_pos: line_start, end_pos: line_start), "\n")
      end
    end

    def needs_empty_line_before?(node)
      SiblingCheck.new(node, previous_sibling(node)).needed?
    end

    def previous_sibling(node)
      return unless node.parent&.begin_type?

      siblings = node.parent.children
      node_index = siblings.index(node)
      siblings[node_index - 1] if node_index&.positive?
    end

    class SiblingCheck
      include RuboCop::Callbacksystems::Helpers

      def initialize(node, previous_node)
        @node = node
        @previous_node = previous_node
      end

      def needed?
        checkable? && missing_empty_line?
      end

      private
        attr_reader :node, :previous_node

        def checkable?
          previous_node &&
            !first_in_body? &&
            !after_visibility_modifier?
        end

        def missing_empty_line?
          (node.first_line - previous_node.last_line) <= 1
        end

        def first_in_body?
          ParentCheck.new(node, node.parent).first_in_body?
        end

        def after_visibility_modifier?
          !visibility_modifier(previous_node).nil?
        end
    end

    class ParentCheck
      def initialize(node, parent)
        @node = node
        @parent = parent
      end

      def first_in_body?
        return true unless parent

        case parent.type
        when :begin
          first_in_begin?
        when :class, :module, :sclass
          parent.body == node
        else
          false
        end
      end

      private
        attr_reader :node, :parent

        def first_in_begin?
          return false unless parent.children.first == node

          grandparent = parent.parent
          grandparent.nil? || grandparent.block_type? || grandparent.class_type? || grandparent.module_type?
        end
    end
end
