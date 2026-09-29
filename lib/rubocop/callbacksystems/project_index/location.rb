# One source location expressed in Rubydex's zero-based lines and byte columns, so parser ranges and graph locations can
# be compared without confusing a character column for a byte column.
class RuboCop::Callbacksystems::ProjectIndex::Location < Data.define \
  :uri, :start_line, :start_column, :end_line, :end_column
  class << self
    def for_ast(range, uri:)
      new \
        uri:,
        start_line: range.line.pred,
        start_column: byte_column_of(range, line: range.line, at: range.column),
        end_line: range.last_line.pred,
        end_column: byte_column_of(range, line: range.last_line, at: range.last_column)
    end

    def for_rubydex(location)
      new \
        uri: location.uri,
        start_line: location.start_line,
        start_column: location.start_column,
        end_line: location.end_line,
        end_column: location.end_column
    end

    private
      def byte_column_of(range, line:, at:)
        range.source_buffer.source_line(line).slice(0, at).bytesize
      end
  end
end
