module RuboCop::Callbacksystems::Helpers::Comments
  def holds_comment?(range, comments)
    first_comment_in(range, comments).present?
  end

  def first_comment_in(range, comments)
    comments.find { range.contains?(it.source_range) }
  end

  def comments_in(range, comments)
    comments.select { range.contains?(it.source_range) }
  end

  # For a deletion whose surviving code is below, so the comment reads as written about it.
  def range_ending_at_first_comment(range, comments)
    comment = first_comment_in(range, comments)
    comment ? range.with(end_pos: comment.source_range.begin_pos) : range
  end

  # The mirror: the surviving code is above, so the comment stays under it.
  def range_starting_after_last_comment(range, comments)
    comment = last_comment_in(range, comments)
    comment ? range.with(begin_pos: comment.source_range.end_pos) : range
  end

  def last_comment_in(range, comments)
    comments.rfind { range.contains?(it.source_range) }
  end

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
