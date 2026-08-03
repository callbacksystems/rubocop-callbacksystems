# The heredoc bodies an expression carries. Each one sits below the line its
# `<<~TAG` marker is on, outside the expression's own range, so a fixer that
# rewrites that range has to write the bodies out again under the line that
# survives. Without this a collapse leaves a marker with nothing to close it.
class RuboCop::Callbacksystems::HeredocBodies
  include RuboCop::Callbacksystems::Helpers

  def initialize(node)
    @node = node
  end

  # Re-emitted directly under the line the expression ends on, which is where
  # its markers now are. `<<~` measures the indentation of the body itself, so
  # the strings keep their value wherever that line ends up.
  def relocate(corrector)
    relocate_under(corrector, node)
  end

  # When the fixer moves a marker somewhere else entirely, the body lands under
  # the line it went to instead.
  def relocate_under(corrector, destination)
    corrector.insert_before(landing_after(destination), text) if heredocs.any?
  end

  # And it leaves where it was, or it stays behind as loose code. Lines the
  # caller already removes are left to it: two removals over one range is an
  # overlap the corrector refuses.
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

    # Clamped to the end of the file, where a last line carrying no newline of
    # its own leaves nothing to land after.
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

    # The newline the clamp could not find, so the first body still starts on a
    # line of its own.
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
