# The place a statement takes in the order a class body reads: the mixins and the class attribute assignments first,
# then the values, the classes declared in a line, the state, the associations, the delegates, the other macros, the
# methods, and last the nested classes with a body of their own. The siblings are the statements of the same body, which
# a `private_constant` needs to find the constant it hides.
class RuboCop::Callbacksystems::ClassStructure::StatementRank
  include RuboCop::Callbacksystems::Helpers

  MIXIN = 0
  VALUE = 1
  CLASS_DECLARATION = 2
  ATTRIBUTE = 3
  ASSOCIATION = 4
  DELEGATE = 5
  MACRO = 6
  METHOD = 7
  NESTED_CLASS = 8

  def initialize(node, siblings)
    @node = node
    @siblings = siblings
  end

  def to_i
    shape_rank || marker_rank || macro_rank || METHOD
  end

  private
    attr_reader :node, :siblings

    def shape_rank
      if nested_body?(statement)
        NESTED_CLASS
      elsif statement.casgn_type?
        value_name? ? VALUE : CLASS_DECLARATION
      end
    end

    # `include Detection if Rails.env.local?` is the include, whatever the condition around it.
    def statement
      node.if_type? && node.modifier_form? ? node.if_branch : node
    end

    # `Naming/ConstantName` wants SCREAMING_SNAKE_CASE on a value and not on a class, so the case tells them apart.
    def value_name?
      statement.name.match?(/\A[A-Z][A-Z0-9_]*\z/)
    end

    # `private_constant :X` belongs with the `X` it hides, so it takes that declaration's rank.
    def marker_rank
      marked_ranks.max || VALUE if private_constant_marker?
    end

    def private_constant_marker?
      bare_send?(macro) && macro.method?(:private_constant)
    end

    # `has_many :blocks do ... end` is the `has_many`, whatever the block adds to it.
    def macro
      call_of(statement)
    end

    def marked_ranks
      siblings.select { marked_names.include?(declared_name_of(it)) }
        .map { self.class.new(it, siblings).to_i }
    end

    def marked_names
      @marked_names ||= private_constant_names_of(node)
    end

    def macro_rank
      case
      when mixin_macro?(macro) || class_attribute_assignment? then MIXIN
      when attribute_macro?(macro) then ATTRIBUTE
      when association_macro?(macro) then ASSOCIATION
      when delegate_macro?(macro) then DELEGATE
      when bare_send?(macro) then MACRO
      end
    end

    def class_attribute_assignment?
      statement.send_type? && statement.receiver&.self_type? && statement.assignment_method?
    end
end
