# A class body reads in sections: the mixins, the constants, the declarations of its state, the macros, the methods,
# and the nested classes. A blank line is what tells the reader one section has ended and the next begins, so two
# adjacent statements of different sections need one between them, while the statements of one section sit together
# or apart as the author likes. `BodyOrder` owns the order the sections come in, and this cop asks only for the blank
# line, whichever way round the two statements sit.
#
# The sections are coarser than the ranks `BodyOrder` reads. An `attribute`, an association and a `delegate` all
# declare what the object holds, so they are one section, the way the authentication generator writes
# `attribute :session` right above `delegate :user, ...` and `has_secure_password` right above `has_many :sessions`.
#
# A visibility modifier belongs to no section, so the pair it makes with the statement on either side is left to the
# Layout cops.
#
# @example
#   # bad - the token sits pressed against the constant
#   class Key < ApplicationRecord
#     PREFIX = "key_"
#     has_secure_token :value
#   end
#
#   # good
#   class Key < ApplicationRecord
#     PREFIX = "key_"
#
#     has_secure_token :value
#   end
#
#   # good - the state declarations are one section
#   class Current < ActiveSupport::CurrentAttributes
#     attribute :session
#     delegate :user, to: :session, allow_nil: true
#   end
#
class RuboCop::Cop::Callbacksystems::EmptyLineBetweenSections < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  def on_class(node)
    report_each Body.new(node.body, processed_source)
  end

  alias on_module on_class
  alias on_sclass on_class

  private
    class Body
      include RuboCop::Callbacksystems::Helpers

      def initialize(body, processed_source)
        @body = body
        @processed_source = processed_source
      end

      def each_offense(&block)
        statements.each_cons(2).filter_map { |above, below| Boundary.new(above:, below:).offense }.each(&block)
      end

      private
        attr_reader :body, :processed_source

        def statements
          @statements ||= nodes.map { Statement.new(it, nodes, processed_source) }
        end

        def nodes
          @nodes ||= statements_in(body)
        end
    end

    # Two statements written one after the other, read for the sections they belong to.
    class Boundary
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Separate `%<statement>s` from the %<above>s above with a blank line, since the %<below>s are " \
        "another section."

      def initialize(above:, below:)
        @above = above
        @below = below
      end

      def offense
        if crowded?
          RuboCop::Callbacksystems::Offense.new(below.node, message, correcting: source_ordered?) { correct(it) }
        end
      end

      private
        attr_reader :above, :below

        def crowded?
          crosses_sections? && !below.separated_from?(above)
        end

        def crosses_sections?
          [ above, below ].none?(&:visibility_modifier?) && above.section != below.section
        end

        def message
          format(MESSAGE, statement: below.opening_line, above: above.section, below: below.section)
        end

        def source_ordered?
          above.last_line <= below.node.first_line
        end

        def correct(corrector)
          if above.last_line == below.node.first_line
            corrector.replace \
              above.node.source_range.end.join(below.node.source_range.begin),
              "\n\n#{indentation_of(above.node)}"
          else
            corrector.insert_before(below.line_start, "\n")
          end
        end
    end

    class Statement
      include RuboCop::Callbacksystems::Helpers

      SECTIONS = {
        RuboCop::Callbacksystems::ClassStructure::StatementRank::MIXIN => "mixins",
        RuboCop::Callbacksystems::ClassStructure::StatementRank::VALUE => "constants",
        RuboCop::Callbacksystems::ClassStructure::StatementRank::CLASS_DECLARATION => "constants",
        RuboCop::Callbacksystems::ClassStructure::StatementRank::ATTRIBUTE => "declarations",
        RuboCop::Callbacksystems::ClassStructure::StatementRank::ASSOCIATION => "declarations",
        RuboCop::Callbacksystems::ClassStructure::StatementRank::DELEGATE => "declarations",
        RuboCop::Callbacksystems::ClassStructure::StatementRank::MACRO => "macros",
        RuboCop::Callbacksystems::ClassStructure::StatementRank::METHOD => "methods",
        RuboCop::Callbacksystems::ClassStructure::StatementRank::NESTED_CLASS => "nested classes"
      }

      attr_reader :node

      def initialize(node, siblings, processed_source)
        @node = node
        @siblings = siblings
        @processed_source = processed_source
      end

      def visibility_modifier?
        visibility_modifier_of(node).present?
      end

      def section
        @section ||= SECTIONS.fetch(RuboCop::Callbacksystems::ClassStructure::StatementRank.new(node, siblings).to_i)
      end

      def separated_from?(above)
        processed_source.lines[above.last_line...(node.first_line - 1)].any?(&:blank?)
      end

      def last_line
        range_through_heredocs(node).last_line
      end

      def opening_line
        node.source.lines.first.strip
      end

      # The blank line goes above the comments introducing the statement, which travel with it.
      def line_start
        position = RuboCop::Callbacksystems::Source::StatementWithComments.new(node, processed_source).begin_position
        node.source_range.with(begin_pos: position, end_pos: position)
      end

      private
        attr_reader :siblings, :processed_source
    end
end
