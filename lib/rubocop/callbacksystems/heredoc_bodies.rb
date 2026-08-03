# A heredoc body sits below the line its marker is on, outside the range a fixer
# rewrites, so a collapse has to write it out again under the line that survives.
class RuboCop::Callbacksystems::HeredocBodies
  include RuboCop::Callbacksystems::Helpers

  def initialize(node)
    @node = node
  end

  def relocate(corrector)
    relocate_under(corrector, node)
  end

  def relocate_under(corrector, destination)
    corrector.insert_before(landing_after(destination), text) if heredocs.any?
  end

  # Two removals over one range is an overlap the corrector refuses.
  def remove(corrector, covered_by:)
    heredocs.map { whole_lines_of(it) }.reject { covered_by&.contains?(it) }.each { corrector.remove(it) }
  end

  private
    attr_reader :node

    def heredocs
      @heredocs ||= [ node, *node.each_descendant(:str, :dstr, :xstr) ].select { heredoc_literal?(it) }
    end

    def landing_after(destination)
      position = landing_position_after(destination)
      destination.source_range.with(begin_pos: position, end_pos: position)
    end

    def landing_position_after(destination)
      [ closing_line_of(destination).end_pos + 1, buffer.source.length ].min
    end

    def closing_line_of(destination)
      buffer.line_range(buffer.line_for_position(destination.source_range.end_pos))
    end

    def buffer
      node.source_range.source_buffer
    end

    def text
      "#{missing_newline}#{heredocs.map { body_of(it) }.join}"
    end

    def missing_newline
      closing_line_of(node).end_pos < buffer.source.length ? "" : "\n"
    end

    def body_of(heredoc)
      "#{heredoc.loc.heredoc_body.source}#{heredoc.loc.heredoc_end.source}\n"
    end

    def whole_lines_of(heredoc)
      heredoc.loc.heredoc_body.join(heredoc.loc.heredoc_end).then { it.with(end_pos: it.end_pos + 1) }
    end
end
