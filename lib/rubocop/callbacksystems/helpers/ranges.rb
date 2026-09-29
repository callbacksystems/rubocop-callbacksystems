module RuboCop::Callbacksystems::Helpers::Ranges
  include RuboCop::Cop::RangeHelp, RuboCop::Cop::Util

  def statement_removal_range_for(node)
    inline_statement_removal_range_for(node) || statement_removal_range_of(node.source_range)
  end

  # The buffer given explicitly is what frees this from a cop's processed source, so plain objects can use it too.
  def statement_removal_range_of(source_range)
    range = range_by_whole_lines(source_range, include_final_newline: true, buffer: source_range.source_buffer)
    blank_line_above(range) || blank_line_below(range) || range
  end

  # Statements with only blank lines between them share one range, so their removal takes one blank line, not one each.
  def statement_removal_ranges_of(source_ranges)
    source_ranges
      .slice_when { |left, right| code_between?(left, right) }
      .map { statement_removal_range_of(span_of(it)) }
  end

  def span_of(ranges)
    ranges.first.join(ranges.last)
  end

  def line_removal_range_for(node)
    line_removal_range_of(node.source_range)
  end

  def line_removal_range_of(source_range)
    range_by_whole_lines(source_range, include_final_newline: true, buffer: source_range.source_buffer)
  end

  def indentation_of(node)
    " " * node.source_range.column
  end

  def call_prefix_of(node)
    node.source_range.with(end_pos: node.loc.selector.begin_pos).source
  end

  def carries_heredoc?(node)
    node.each_node(:str, :dstr, :xstr).any? { it.loc?(:heredoc_body) }
  end

  def range_through_heredocs(node)
    node.source_range.with(end_pos: [ node.source_range.end_pos, *heredoc_ends_in(node) ].max)
  end

  def range_spanning(nodes)
    span_of(nodes.map(&:source_range))
  end

  def fits_on_line?(node, source, max_line_length)
    node.source_range.column + source.length + trailing_length_of(node) <= max_line_length
  end

  def trailing_length_of(node)
    ending = node.source_range.end
    ending.source_line.length - ending.column
  end

  def line_start_position_of(node)
    range = node.source_range
    range.begin_pos - range.column
  end

  private
    def inline_statement_removal_range_for(node)
      if same_line_siblings?([ node, node.right_sibling ])
        node.source_range.with(end_pos: node.right_sibling.source_range.begin_pos)
      elsif same_line_siblings?([ node.left_sibling, node ])
        node.source_range.with(begin_pos: node.left_sibling.source_range.end_pos)
      end
    end

    def same_line_siblings?(nodes)
      left, right = nodes

      left && right && left.parent.type?(:begin, :kwbegin) && left.parent.equal?(right.parent) &&
        left.last_line == right.first_line
    end

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
      end_of_blank = [ buffer.line_range(line).end_pos + 1, buffer.source.length ].min
      range.with(end_pos: end_of_blank) if blank_line?(buffer, line)
    end

    def code_between?(left, right)
      left.end.join(right.begin).source.strip.present?
    end

    def heredoc_ends_in(node)
      node.each_node(:str, :dstr, :xstr).filter_map { it.loc.heredoc_end.end_pos if it.loc?(:heredoc_end) }
    end
end
