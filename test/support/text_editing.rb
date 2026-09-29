module TextEditing
  private
    def edits_for(correction)
      ->(corrector) { correction.call(Edits.new(corrector)) }
    end

    class Edits
      def initialize(corrector)
        @corrector = corrector
      end

      def replace(text, replacement)
        corrector.replace(range_of(text), replacement)
      end

      def remove(text)
        corrector.remove(range_of(text))
      end

      private
        attr_reader :corrector

        def range_of(text)
          start = corrector.source_buffer.source.index(text)
          corrector.source_buffer.source_range.with(begin_pos: start, end_pos: start + text.size)
        end
    end
end
