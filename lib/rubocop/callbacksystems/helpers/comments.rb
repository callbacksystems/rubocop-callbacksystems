module RuboCop::Callbacksystems::Helpers::Comments
  TOOLING_MARKER = %r{
    \A\#\s*
    (?:
      :?[a-z][\w-]*(?::[a-z][\w-]*)+:?
      |
      :[a-z][\w-]*:
      |
      (?:typed|rbs_inline):\s+(?:disabled|enabled|false|ignore|strict|strong|true|weak)
      |
      @(?:dynamic|implements|rbs|type)
      |
      :?(?:nocov|nodoc):?
      |
      [a-z][\w-]*-ignore
    )
    (?:\s|\z)
  }ix

  def comment_removal_range_for(comment)
    own_line_comment?(comment) ? line_removal_range_for(comment) : trailing_comment_range_for(comment)
  end

  def own_line_comment?(comment)
    range = comment.source_range
    range.source_line[0...range.column].strip.empty?
  end

  def comment_blocks_in(processed_source, reject_tooling_runs: false)
    RuboCop::Callbacksystems::Source::CommentBlocks.new(processed_source, reject_tooling_runs:)
  end

  def prose_comments_in(processed_source)
    processed_source.comments.reject { tooling_comment?(it) }
  end

  def tooling_comment?(comment)
    comment.text.start_with?("#!") || RuboCop::MagicComment.parse(comment.text).any? ||
      RuboCop::DirectiveComment.new(comment).start_with_marker? || rdoc_directive?(comment) ||
      comment.text.match?(TOOLING_MARKER)
  end

  private
    def trailing_comment_range_for(comment)
      range = comment.source_range
      range.with(begin_pos: range.begin_pos - range.column + code_before(range).rstrip.length)
    end

    def code_before(range)
      range.source_line[0...range.column]
    end

    def rdoc_directive?(comment)
      comment.text.match?(/\A#(?:--|\+\+)\s*\z/)
    end
end
