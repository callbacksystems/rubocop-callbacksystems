module RuboCop::Callbacksystems::Helpers::Comments
  def comment_removal_range_for(comment)
    own_line_comment?(comment) ? line_removal_range_for(comment) : trailing_comment_range_for(comment)
  end

  def own_line_comment?(comment)
    range = comment.source_range
    range.source_line[0...range.column].strip.empty?
  end

  private
    def trailing_comment_range_for(comment)
      range = comment.source_range
      range.with(begin_pos: range.begin_pos - range.column + code_before(range).rstrip.length)
    end

    def code_before(range)
      range.source_line[0...range.column]
    end
end
