# A class body reads in one order: the mixins and the class attribute assignments that say what it is made of, then
# the values it holds, then the classes it declares in a line, then the `attr_reader`, `attribute` and
# `class_attribute` that hold its state, then the associations it stands in, then the `delegate` that reaches through
# them, then the macros that declare its behavior, then the methods, and last the nested classes with a body of their
# own.
#
# A constant tells values from classes by the case of its name rather than by what built it: `Naming/ConstantName` asks
# for SCREAMING_SNAKE_CASE on a plain value and only lets a name off when the value comes from a call, which is how a
# class gets built. So `COLUMNS` reads as a value and `Row` as a class, whether it came from `Data.define`, `Struct.new`
# or a method of your own.
#
# A method is never the one at fault. `MethodInvocationOrder` owns the order of those, so a nested class written above
# the methods is reported once, on the class, rather than once per method it sits over.
#
# Nothing moves over a name it reads. A value built from a nested class, or a mixin naming a module declared there, is
# read while the body loads, so the two keep the order they were written in.
#
# `Layout/ClassStructure` lists no category for constants, since putting one there would forbid declaring them in the
# private section, and it lets an `attr_reader` sit below a method, so the whole order lives here instead and that cop
# ships off. Leaving both on has them rewrite the same statement in one pass, which breaks the file.
#
# @example
#   # bad - the constant sits below the method that reads it
#   class Report
#     def total
#       COLUMNS.size
#     end
#
#     COLUMNS = [ :name, :amount ]
#   end
#
#   # good
#   class Report
#     COLUMNS = [ :name, :amount ]
#
#     def total
#       COLUMNS.size
#     end
#   end
#
#   # bad - the reader comes before the constant, and the class before both
#   class Report
#     Row = Data.define(:name)
#     attr_reader :rows
#     COLUMNS = [ :name ]
#   end
#
#   # good
#   class Report
#     COLUMNS = [ :name ]
#     Row = Data.define(:name)
#     attr_reader :rows
#   end
#
#   # bad - the nested class sits above the methods
#   class Report
#     class Row
#       def to_s = name
#     end
#
#     def rows
#       [ Row.new ]
#     end
#   end
#
#   # good
#   class Report
#     def rows
#       [ Row.new ]
#     end
#
#     class Row
#       def to_s = name
#     end
#   end
#
class RuboCop::Cop::Callbacksystems::BodyOrder < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  def on_new_investigation
    report_each Bodies.new(processed_source)
  end

  private
    class Bodies
      include RuboCop::Callbacksystems::Helpers

      def initialize(processed_source)
        @processed_source = processed_source
      end

      def each_offense(&block)
        lifts.each { it.each_offense(&block) }
        sinks.each { it.each_offense(&block) }
      end

      private
        attr_reader :processed_source

        def lifts
          @lifts ||= sections.map { Lifts.new(it) }
        end

        def sections
          @sections ||= bodies.flat_map { sections_of(it) }
        end

        def bodies
          nodes_in(processed_source.ast, :class, :module, :sclass)
        end

        def sections_of(node)
          statements_in(node.body)
            .slice_when { |_, right| visibility_modifier_of(right) }
            .map { Entries.new(it.reject { visibility_modifier_of(it) }, processed_source) }
        end

        def sinks
          @sinks ||= sections.map { Sinks.new(it, permit: permit) }
        end

        # A lift rewrites the span the classes sit in, and a class carries everything inside it, so one per pass.
        def permit
          @permit ||= RuboCop::Callbacksystems::Autocorrection::RewritePermit.new(granted: lifts.none?(&:any?))
        end
    end

    class Entries
      include Enumerable

      delegate :each, to: :statements

      def initialize(nodes, processed_source)
        @nodes = nodes
        @processed_source = processed_source
      end

      def blocker_for(declaration)
        take_while { it.begin_position < declaration.begin_position }.find { it.rank > declaration.rank }
      end

      def methods_below(nested_class)
        select { it.method? && it.begin_position > nested_class.begin_position }
      end

      def declarations
        select(&:liftable?)
      end

      def method_precedence_kept?
        reordered_pairs.all?(&:precedence_kept?)
      end

      # A comment unattached to either statement divides the body into semantic sections.
      def uninterrupted?
        each_cons(2).none? { |above, below| above.range.end.join(below.range.begin).source.strip.present? }
      end

      def tooling_scope_kept?
        none?(&:contains_tooling_comment?)
      end

      def anchor
        find(&:body?)
      end

      private
        attr_reader :nodes, :processed_source

        def statements
          @statements ||= nodes.map { Statement.new(it, nodes, processed_source) }
        end

        def reordered_pairs
          each_with_index.flat_map do |first, index|
            drop(index.next).map { ReorderedPair.new(first, it) }.select(&:order_changes?)
          end
        end

        class ReorderedPair < Data.define(:first, :second)
          def order_changes?
            second.liftable? && (!first.liftable? || first.rank > second.rank)
          end

          def precedence_kept?
            if first_names&.empty? || second_names&.empty?
              true
            else
              first_names && second_names && !first_names.intersect?(second_names)
            end
          end

          private
            def first_names
              first.defined_method_names
            end

            def second_names
              second.defined_method_names
            end
        end
    end

    # Statements out of place, whose first offense carries the rewrite for the whole group.
    class Misplacements
      include Enumerable

      ORDER = "a body reads what it holds, then what it does, then its nested classes."

      delegate :each, to: :misplaced

      def initialize(entries)
        @entries = entries
      end

      def each_offense
        rewriting = correctable?
        each_with_index do |statement, index|
          yield RuboCop::Callbacksystems::Offense.new(statement.node, message_for(statement),
            correcting: rewriting && index.zero?) { rewrite(it) }
        end
      end

      private
        attr_reader :entries
    end

    class Lifts < Misplacements
      MESSAGE = "Move `%<name>s` above `%<blocker>s`; #{ORDER}"

      private
        def misplaced
          @misplaced ||= entries.select { it.liftable? && entries.blocker_for(it) && it.movable? }
        end

        # The rewrite spans every declaration at once, so one that cannot move would be written over.
        def correctable?
          entries.uninterrupted? && entries.tooling_scope_kept? && entries.declarations.all?(&:movable?) &&
            entries.method_precedence_kept?
        end

        def message_for(declaration)
          format(MESSAGE, name: declaration.name, blocker: entries.blocker_for(declaration).opening_line)
        end

        def rewrite(corrector)
          Reordering.new(entries.declarations, entries.anchor, corrector).rewrite
        end
    end

    # The nested classes sitting above what the body does, which `MethodInvocationOrder` never moves.
    class Sinks < Misplacements
      MESSAGE = "Move `%<name>s` below `%<blocked>s`; #{ORDER}"

      def initialize(entries, permit:)
        super(entries)
        @permit = permit
      end

      private
        attr_reader :permit

        def correctable?
          any? && entries.uninterrupted? && entries.tooling_scope_kept? && permit.claim
        end

        def message_for(nested_class)
          format(MESSAGE, name: nested_class.name, blocked: entries.methods_below(nested_class).first.opening_line)
        end

        def rewrite(corrector)
          Sinking.new(misplaced, entries.to_a.last, corrector).rewrite
        end

        def misplaced
          @misplaced ||= entries.select { it.nested_class? && entries.methods_below(it).any? && sinkable?(it) }
        end

        # A declaration naming the class reads it while the body loads.
        def sinkable?(nested_class)
          entries.declarations.none? { it.reads?(nested_class.declared_name) }
        end
    end

    class Reordering
      include RuboCop::Callbacksystems::Helpers

      def initialize(declarations, anchor, corrector)
        @declarations = declarations
        @anchor = anchor
        @corrector = corrector
      end

      def rewrite
        leading.any? ? replace_leading_span : insert_above_anchor
        statement_removal_ranges_of(trailing.map(&:range)).each { corrector.remove(it) }
      end

      private
        attr_reader :declarations, :anchor, :corrector

        def leading
          anchor ? declarations.reject { below_anchor?(it) } : declarations
        end

        def below_anchor?(declaration)
          declaration.begin_position > anchor.begin_position
        end

        def replace_leading_span
          corrector.replace(span_of(leading.map(&:range)), ordered_source)
        end

        def ordered_source
          ordered.map(&:source).zip(separators).join
        end

        def ordered
          @ordered ||= declarations.sort_by.with_index { |declaration, index| [ declaration.rank, index ] }
        end

        def separators
          ordered.each_cons(2).map { |above, below| Neighbors.new(above:, below:, declarations:).separator } + [ "" ]
        end

        def insert_above_anchor
          corrector.insert_before(anchor.range, "#{ordered_source}\n\n")
        end

        def trailing
          declarations - leading
        end
    end

    # Two declarations landing next to each other, kept apart only by a blank line the author wrote between them.
    class Neighbors
      BLANK_LINE = /\n[ \t]*\n/

      def initialize(above:, below:, declarations:)
        @above = above
        @below = below
        @declarations = declarations
      end

      def separator
        blank_written? ? "\n\n" : "\n"
      end

      private
        attr_reader :above, :below, :declarations

        def blank_written?
          declarations.each_cons(2).any? do |first, second|
            written_span.cover?(first.begin_position) && blank_line_between?(first, second)
          end
        end

        def written_span
          earlier, later = [ above, below ].map(&:begin_position).sort
          earlier...later
        end

        def blank_line_between?(first, second)
          first.range.end.join(second.range.begin).source.match?(BLANK_LINE)
        end
    end

    class Sinking
      include RuboCop::Callbacksystems::Helpers

      def initialize(nested_classes, tail, corrector)
        @nested_classes = nested_classes
        @tail = tail
        @corrector = corrector
      end

      def rewrite
        corrector.insert_after(tail.range, "\n\n#{ordered_source}")
        statement_removal_ranges_of(nested_classes.map(&:range)).each { corrector.remove(it) }
      end

      private
        attr_reader :nested_classes, :tail, :corrector

        def ordered_source
          nested_classes.map(&:source).join("\n\n")
        end
    end

    class Statement
      include RuboCop::Callbacksystems::Helpers

      attr_reader :node

      delegate :range, :source, :contains_tooling_comment?, to: :block

      def initialize(node, statements, processed_source)
        @node = node
        @statements = statements
        @processed_source = processed_source
      end

      def liftable?
        rank <= RuboCop::Callbacksystems::ClassStructure::StatementRank::MACRO
      end

      def rank
        @rank ||= RuboCop::Callbacksystems::ClassStructure::StatementRank.new(node, statements).to_i
      end

      def method?
        rank == RuboCop::Callbacksystems::ClassStructure::StatementRank::METHOD
      end

      def nested_class?
        rank == RuboCop::Callbacksystems::ClassStructure::StatementRank::NESTED_CLASS
      end

      def body?
        rank >= RuboCop::Callbacksystems::ClassStructure::StatementRank::METHOD
      end

      # Only a read declaration of a higher rank would sort above this one, so any other moves along with it.
      def movable?
        declarations_read_before.none? { it.rank > rank }
      end

      def reads?(constant_name)
        constant_name && names_read.include?(constant_name)
      end

      def declared_name
        declared_name_of(node)
      end

      def begin_position
        node.source_range.begin_pos
      end

      def name
        node.casgn_type? ? node.name : opening_line
      end

      def opening_line
        node.source.lines.first.strip
      end

      def defined_method_names
        @defined_method_names ||= RuboCop::Callbacksystems::Methods::StatementDefinitions.new(node).names
      end

      private
        attr_reader :statements, :processed_source

        def block
          @block ||= RuboCop::Callbacksystems::Source::StatementWithComments.new(node, processed_source)
        end

        def declarations_read_before
          statements.take_while { !it.equal?(node) }
            .select { names_read.include?(declared_name_of(it)) }
            .map { self.class.new(it, statements, processed_source) }
        end

        # A `private_constant :X` reads the `X` it hides.
        def names_read
          @names_read ||= node.each_descendant(:const, :lvar, :send).filter_map { read_name_of(it) }.to_set
            .merge(private_constant_names_of(node))
        end

        def read_name_of(descendant)
          if descendant.const_type? then descendant.short_name
          elsif descendant.lvar_type? then descendant.name
          elsif bare_send?(descendant) && descendant.arguments.empty? then descendant.method_name
          end
        end
    end
end
