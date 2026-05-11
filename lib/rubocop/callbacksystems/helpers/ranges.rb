module RuboCop::Callbacksystems::Helpers::Ranges
  def line_removal_range(node)
    range = node.source_range
    line_end = range.source_buffer.source[range.end_pos] == "\n" ? range.end_pos + 1 : range.end_pos
    Parser::Source::Range.new(range.source_buffer, range.begin_pos - range.column, line_end)
  end
end
