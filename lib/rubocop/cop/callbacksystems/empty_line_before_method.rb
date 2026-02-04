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
class RuboCop::Cop::Callbacksystems::EmptyLineBeforeMethod < RuboCop::Cop::Base
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = "Add an empty line before `%<method>s`."
  VISIBILITY_MODIFIERS = %i[private protected public].freeze

  def on_def(node)
    check_empty_line_before(node)
  end

  def on_defs(node)
    check_empty_line_before(node)
  end

  private
    def check_empty_line_before(node)
      return unless needs_empty_line_before?(node)

      add_offense(node, message: format(MESSAGE, method: node.method_name)) do |corrector|
        line_start = node.source_range.begin_pos - node.source_range.column
        corrector.insert_before(node.source_range.with(begin_pos: line_start, end_pos: line_start), "\n")
      end
    end

    def needs_empty_line_before?(node)
      previous_node = previous_sibling(node)
      checkable?(node, previous_node) && missing_empty_line?(node, previous_node)
    end

    def checkable?(node, previous_node)
      previous_node &&
        !first_in_body?(node) &&
        !after_visibility_modifier?(previous_node)
    end

    def missing_empty_line?(node, previous_node)
      !empty_line_between?(previous_node, node)
    end

    def first_in_body?(node)
      parent = node.parent
      first_in_body_for_parent?(node, parent)
    end

    def first_in_body_for_parent?(node, parent)
      return true unless parent

      case parent.type
      when :begin
        first_in_begin?(node, parent)
      when :class, :module, :sclass
        parent.body == node
      else
        false
      end
    end

    def first_in_begin?(node, parent)
      return false unless parent.children.first == node

      grandparent = parent.parent
      grandparent.nil? || grandparent.block_type? || grandparent.class_type? || grandparent.module_type?
    end

    def after_visibility_modifier?(previous_node)
      visibility_modifier?(previous_node)
    end

    def visibility_modifier?(node)
      node.send_type? && VISIBILITY_MODIFIERS.include?(node.method_name) && node.arguments.empty?
    end

    def previous_sibling(node)
      return unless node.parent&.begin_type?

      siblings = node.parent.children
      node_index = siblings.index(node)
      siblings[node_index - 1] if node_index&.positive?
    end

    def empty_line_between?(first_node, second_node)
      first_line = first_node.last_line
      second_line = second_node.first_line
      (second_line - first_line) > 1
    end
end
