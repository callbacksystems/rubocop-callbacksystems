# Whether an expression's value is ignored, following final values through sequences and definition bodies.
class RuboCop::Callbacksystems::Execution::DiscardedExpression
  def initialize(expression)
    @current = expression
  end

  def discarded?
    disposition == :discarded
  end

  private
    attr_reader :current
    delegate :parent, to: :current, private: true

    def disposition
      advance until @disposition
      @disposition
    end

    def advance
      if parent.nil? || discarded_sequence?
        @disposition = :discarded
      elsif transparent?
        @current = parent
      else
        @disposition = :observed
      end
    end

    def discarded_sequence?
      sequence? && current.right_sibling
    end

    def sequence?
      parent.type?(:begin, :kwbegin)
    end

    def transparent?
      sequence? || definition_body?
    end

    def definition_body?
      parent.type?(:class, :module, :sclass) && parent.body.equal?(current)
    end
end
