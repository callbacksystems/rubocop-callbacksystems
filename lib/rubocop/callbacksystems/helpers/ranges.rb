module RuboCop::Callbacksystems::Helpers::Ranges
  # The statement's own lines plus one adjacent blank line, the one above when
  # there is one and the one below otherwise, so removing a statement does not
  # leave a stray blank where it used to sit.
  def statement_removal_range_for(node)
    range = line_removal_range_for(node)
    blank_line_above(range) || blank_line_below(range) || range
  end

  def line_removal_range_for(node)
    range = node.source_range
    line_end = range.source_buffer.source[range.end_pos] == "\n" ? range.end_pos + 1 : range.end_pos
    Parser::Source::Range.new(range.source_buffer, range.begin_pos - range.column, line_end)
  end

  def indentation_of(node)
    " " * node.source_range.column
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
end
