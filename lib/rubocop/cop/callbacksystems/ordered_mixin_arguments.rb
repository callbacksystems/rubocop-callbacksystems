# Ensures the modules of one mixin call are sorted alphabetically.
#
# Putting several modules in one `include` is a claim that their order does not
# matter, and once that holds they may as well read alphabetically. When the
# order does matter, the modules belong on separate lines where the precedence
# is written down rather than implied. Separate calls are left alone: it is the
# comma that makes the claim, so only what shares one is sorted.
#
# Ruby resolves `include A, B` to the ancestors `[A, B]` and `include B, A` to
# `[B, A]`, so sorting is only a rewrite of the appearance when no two modules
# define the same method. The cop cannot see the modules to know, which is why
# the correction is marked unsafe, so the unsafe autocorrect pass sorts and the
# safe one leaves it alone, and a collision is the case to split onto separate lines
# instead.
#
# @example
#   # bad - unsorted
#   include Searchable, Confirmable, Accessible
#
#   # good - sorted alphabetically
#   include Accessible, Confirmable, Searchable
#
#   # good - single module (nothing to sort)
#   include Searchable
#
#   # good - separate lines (each line is independent)
#   include Searchable
#   include Confirmable  # depends on Searchable
#
#   # bad - a note travels with the module it was written about
#   include Searchable, # only for confirmed accounts
#     Confirmable
#
#   # good
#   # only for confirmed accounts
#   include Confirmable, Searchable
#
class RuboCop::Cop::Callbacksystems::OrderedMixinArguments < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  MIXIN_METHODS = %i[include extend prepend].freeze
  MESSAGE = "Sort mixin arguments alphabetically: `%<sorted>s`. If their order matters, put them on separate lines."

  def on_send(node)
    mixin = MixinCall.new(node, processed_source.comments)
    add_offense(node, message: mixin.offense_message) { mixin.reorder(it) } if mixin.unsorted?
  end

  alias on_csend on_send

  private
    class MixinCall
      include RuboCop::Callbacksystems::Helpers

      def initialize(node, comments)
        @node = node
        @comments = comments
      end

      def unsorted?
        mixin_call? && node.arguments.many? && names != sorted_names
      end

      def offense_message
        format(MESSAGE, sorted: sorted_names.join(", "))
      end

      def reorder(corrector)
        corrector.replace(rewritten_range, sorted_source) if correctable?
      end

      private
        attr_reader :node, :comments
        delegate :arguments, to: :node, private: true

        def mixin_call?
          bare_send?(node) && MIXIN_METHODS.include?(node.method_name)
        end

        def names
          @names ||= arguments.map(&:source)
        end

        def sorted_names
          @sorted_names ||= names.sort
        end

        # Rewriting an annotated list writes the statement out again, which a
        # call sharing its line with other code has no room for.
        def correctable?
          notes.empty? || starts_its_line?
        end

        # A trailing note on a list written across lines belongs to the module on
        # that line; one on a single-line list belongs to the statement.
        def notes
          @notes ||= comments.select { notes_range.contains?(it.source_range) }
        end

        def notes_range
          spans_lines? ? arguments_range.with(end_pos: closing_line.end_pos) : arguments_range
        end

        def spans_lines?
          !arguments_range.single_line?
        end

        def arguments_range
          arguments.first.source_range.join(arguments.last.source_range)
        end

        def closing_line
          buffer.line_range(buffer.line_for_position(arguments_range.end_pos))
        end

        def buffer
          node.source_range.source_buffer
        end

        def starts_its_line?
          node.source_range.source_line[0...node.loc.column].strip.empty?
        end

        def rewritten_range
          notes.empty? ? arguments_range : statement_range
        end

        def statement_range
          arguments_range.with(begin_pos: node.source_range.begin_pos - node.loc.column, end_pos: closing_line.end_pos)
        end

        def sorted_source
          notes.empty? ? sorted_names.join(", ") : annotated_source
        end

        # The notes of whichever module now leads move above the statement: the
        # line it shares with `include` has no room for them.
        def annotated_source
          "#{leading_notes}#{indentation}#{node.method_name} #{listed_mixins}"
        end

        def leading_notes
          sorted_mixins.first.notes_at(indentation)
        end

        def sorted_mixins
          @sorted_mixins ||= mixins.sort_by(&:name)
        end

        def mixins
          @mixins ||= arguments.map { Mixin.new(it.source, notes_for(it)) }
        end

        def notes_for(argument)
          notes.select { owner_of(it).equal?(argument) }.map(&:text)
        end

        # A note on its own line was written above the module it belongs to; one
        # trailing a line was written about the module ending on that line.
        def owner_of(note)
          if own_line_comment?(note)
            arguments.find { it.source_range.begin_pos > note.source_range.end_pos }
          else
            arguments.rfind { it.source_range.end_pos < note.source_range.begin_pos }
          end
        end

        def indentation
          indentation_of(node)
        end

        def listed_mixins
          sorted_mixins.drop(1).reduce(sorted_mixins.first.name) { |list, mixin| "#{list},#{mixin.after(continuation)}" }
        end

        def continuation
          "#{indentation}  "
        end

        class Mixin
          attr_reader :name

          def initialize(name, notes)
            @name = name
            @notes = notes
          end

          # A module carrying a note takes a line of its own; one without stays
          # on the line already running.
          def after(indentation)
            notes.any? ? "\n#{notes_at(indentation)}#{indentation}#{name}" : " #{name}"
          end

          # Above the module, never trailing it: a trailing note would land
          # before the comma once the list is rebuilt.
          def notes_at(indentation)
            notes.map { "#{indentation}#{it}\n" }.join
          end

          private
            attr_reader :notes
        end
    end
end
