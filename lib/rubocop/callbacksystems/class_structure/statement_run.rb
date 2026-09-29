# Statements written together with nothing between them, rewritten into the order given when every one has a place in
# it. The block names each statement the way the order does, and a statement answers `range` and `source`.
class RuboCop::Callbacksystems::ClassStructure::StatementRun
  include RuboCop::Callbacksystems::Helpers

  def initialize(statements, order:, &name_of)
    @statements = statements
    @order = order
    @name_of = name_of
  end

  def rewrite(corrector)
    corrector.replace(range, ordered_source) if reorderable?
  end

  def reorderable?
    ordered != statements && statements.none?(&:contains_tooling_comment?)
  end

  private
    attr_reader :statements, :order, :name_of

    def ordered
      @ordered ||= placed? ? statements.sort_by { positions.fetch(name_of.call(it)) } : statements
    end

    def placed?
      statements.all? { positions.key?(name_of.call(it)) }
    end

    def positions
      @positions ||= order.each_with_index.reverse_each.to_h
    end

    def range
      span_of(statements.map(&:range))
    end

    def ordered_source
      ordered.map(&:source).join("\n\n")
    end
end
