# Comments a fixer is about to write over. They move to their own lines above
# the statement, the only place left that still reads as being about it.
class RuboCop::Callbacksystems::LiftedComments
  include RuboCop::Callbacksystems::Helpers

  def initialize(node, comments)
    @node = node
    @comments = comments
  end

  def lift(corrector)
    corrector.insert_before(statement_start, text) if comments.any?
  end

  private
    attr_reader :node, :comments

    def statement_start
      node.source_range.with(end_pos: node.source_range.begin_pos)
    end

    def text
      comments.map { "#{it.text}\n#{indentation_of(node)}" }.join
    end
end
