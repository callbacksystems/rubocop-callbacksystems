module RuboCop::Callbacksystems::Helpers::Ranges
  include RuboCop::Cop::RangeHelp

  # Takes one adjacent blank line too, so removing a statement leaves no stray
  # blank where it sat.
  def statement_removal_range_for(node)
    range = line_removal_range_for(node)
    blank_line_above(range) || blank_line_below(range) || range
  end

  # The buffer travels explicitly so plain objects can use this too.
  def line_removal_range_for(node)
    range_by_whole_lines(node.source_range, include_final_newline: true, buffer: node.source_range.source_buffer)
  end

  def indentation_of(node)
    " " * node.source_range.column
  end

  # Where a node's source really ends, past any heredoc body below it.
  def source_end_of(node)
    [ node.source_range.end_pos, *heredoc_ends_in(node) ].max
  end

  private
    def blank_line_above(range)
      buffer = range.source_buffer
      line = buffer.line_for_position(range.begin_pos) - 1
      range.with(begin_pos: buffer.line_range(line).begin_pos) if blank_line?(buffer, line)
    end

    def blank_line?(buffer, line)
      line.between?(1, buffer.last_line) && buffer.source_line(line).match?(/\A[ \t]*\z/)
    end

    def blank_line_below(range)
      buffer = range.source_buffer
      line = buffer.line_for_position(range.end_pos)
      range.with(end_pos: [ buffer.line_range(line).end_pos + 1, buffer.source.length ].min) if blank_line?(buffer, line)
    end

    def heredoc_ends_in(node)
      [ node, *node.each_descendant(:str, :dstr, :xstr) ]
        .filter_map { it.loc.heredoc_end.end_pos if heredoc_literal?(it) }
    end
end
