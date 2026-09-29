# A hash literal of several fields, built in one place and read from several
# others, is a concept with no behavior: every caller reaches past it into its
# fields because it has nothing of its own. That is a data clump wearing braces,
# and the same refactor applies. Give it a class, and the methods reading its
# fields become its methods.
#
# What matters is whether the record travels. One built and consumed on the spot,
# an options argument or a payload passed straight to a call, is a return value
# rather than a concept, so only a record that is returned or assigned counts.
#
# A read counts for a record only when it goes through where the record lives:
# the constant or variable it was assigned to, the method returning it, or a
# local a method assigned from one of those. Sharing a few key names proves
# nothing, so `entry[:id]` on a form entry never counts against an unrelated
# hash that also carries an `id`.
#
# A hash returned from `as_json`, `to_h`, `to_hash` or `serializable_hash` is
# the wire format rather than a concept, so it is never a record.
#
# `DataClump` sees the same smell spelled as parameter lists. Bagging a clump into
# a hash silences that cop without changing anything, so this one closes the gap.
#
# @example
#   # bad - three fields and no behavior, read across methods
#   SHAPE = { open: "{", close: "}", items: :children }
#
#   def opening?
#     source == SHAPE[:open]
#   end
#
#   def items
#     node.public_send(SHAPE[:items])
#   end
#
#   # good - the record becomes a class and the readers become its methods
#   class Shape
#     def initialize(open, close, items)
#       @open, @close, @items = open, close, items
#     end
#
#     def opening?(source)
#       source == open
#     end
#   end
#
#   # good - built and consumed on the spot
#   render json: { status: "ok", id: id, name: name }
#
class RuboCop::Cop::Callbacksystems::NoAnemicRecord < RuboCop::Cop::Callbacksystems::Base
  def on_new_investigation
    report_each Records.new \
      processed_source.ast,
      min_fields: cop_config["MinFields"],
      min_readers: cop_config["MinReaders"]
  end

  private
    Home = Data.define(:kind, :name, :domain)

    # The traveling hash literals of a file, each with the reads that go through its home.
    class Records
      include RuboCop::Callbacksystems::Helpers

      def initialize(ast, min_fields:, min_readers:)
        @ast = ast
        @min_fields = min_fields
        @min_readers = min_readers
        @local_variables = RuboCop::Callbacksystems::Execution::LocalVariableOccurrences.new(ast)
      end

      def each_offense
        reached.select { it.readers >= min_readers }.each { yield it.offense }
      end

      private
        attr_reader :ast, :min_fields, :min_readers, :local_variables
        delegate :reading_methods_of, to: :read_index, private: true

        def read_index
          @read_index ||= ReadIndex.new(nodes_in(ast, :send, :csend).map { Read.new(it, local_variables:) })
        end

        def reached
          candidates.map { ReachedRecord.new(it, reading_methods_of(it)) }
        end

        def candidates
          nodes_in(ast, :hash).map { Record.new(it) }.select { it.travels? && it.fields.size >= min_fields }
        end
    end

    # Field reads grouped by the object carrying them, so each record visits only its own reads.
    class ReadIndex
      def initialize(reads)
        @by_container = {}.compare_by_identity
        reads.each { add(it) if it.field && it.home }
      end

      def reading_methods_of(record)
        reads_for(record).filter_map { it.reader if record.fields.include?(it.field) }
      end

      private
        attr_reader :by_container

        def add(read)
          homes = by_container[read.container] ||= {}
          (homes[read.home] ||= []) << read
        end

        def reads_for(record)
          by_container.fetch(record.container) { {} }.fetch(record.home) { [] }
        end
    end

    class Read
      include RuboCop::Callbacksystems::Helpers

      READING_METHODS = %i[ [] fetch dig ]

      def initialize(node, local_variables:)
        @node = node
        @local_variables = local_variables
      end

      def field
        @field ||= node.first_argument.value if reads_a_field?
      end

      # The name the read goes through, which is where the record it reaches has to live.
      def home
        @home ||= home_of(node.receiver)
      end

      def reader
        enclosing_method_of(node)
      end

      def container
        @container ||= domain.container
      end

      private
        attr_reader :node, :local_variables

        def reads_a_field?
          READING_METHODS.include?(node.method_name) && single_symbol_argument?
        end

        def single_symbol_argument?
          node.arguments.one? && node.first_argument.sym_type?
        end

        def home_of(expression)
          case expression&.type
          when :const then Home.new(:constant, constant_name_of(expression), nil)
          when :ivar then Home.new(:instance_variable, expression.name, method_domain)
          when :cvar, :gvar then Home.new(expression.type, expression.name, nil)
          when :send, :csend then method_home_of(expression)
          when :lvar then home_of(Local.new(expression, occurrences: local_variables).origin)
          end
        end

        def method_domain
          domain.identity
        end

        def domain
          @domain ||= RuboCop::Callbacksystems::Methods::Domain.new(node)
        end

        def method_home_of(expression)
          Home.new(:method, expression.method_name, method_domain) if bare_send?(expression) ||
            expression.receiver.self_type?
        end
    end

    # A local stands for the value its method assigned it once, unless that value is another local.
    class Local
      include RuboCop::Callbacksystems::Helpers

      def initialize(variable, occurrences:)
        @variable = variable
        @occurrences = occurrences
      end

      def origin
        expression unless expression&.lvar_type?
      end

      private
        attr_reader :variable, :occurrences

        def expression
          assignment&.expression
        end

        def assignment
          assignments.first if assignments.one? && assignments.first.lvasgn_type?
        end

        def assignments
          occurrences.named_in_method(variable.name, around: variable).select { it.type?(:lvasgn, :match_var) }
        end
    end

    class ReachedRecord
      MESSAGE = "This record carries [%<fields>s] and no behavior, and %<readers>d methods reach into its fields. " \
        "Give it a class and let those become its methods."

      def initialize(record, reading_methods)
        @record = record
        @reading_methods = reading_methods
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(record.node, message)
      end

      def readers
        reading_methods.uniq.size
      end

      private
        attr_reader :record, :reading_methods

        def message
          format(MESSAGE, fields: record.fields.to_a.join(", "), readers: readers)
        end
    end

    class Record
      include RuboCop::Callbacksystems::Helpers

      SERIALIZATION_METHODS = %i[ as_json to_h to_hash serializable_hash ]
      VARIABLE_READ_TYPES = { cvasgn: :cvar, gvasgn: :gvar }

      attr_reader :node

      def initialize(node)
        @node = node
      end

      def travels?
        symbol_keyed? && home.present? && !serialization_output?
      end

      def home
        @home ||= assigned_home || returning_method_home
      end

      def fields
        @fields ||= node.pairs.to_set { it.key.value }
      end

      def container
        @container ||= domain.container
      end

      private
        def symbol_keyed?
          node.pairs.any? && node.pairs.all? { it.key.sym_type? }
        end

        def assigned_home
          case node.parent&.type
          when :casgn then Home.new(:constant, constant_assignment_name, nil)
          when :ivasgn then Home.new(:instance_variable, node.parent.name, method_domain)
          when :cvasgn, :gvasgn then Home.new(VARIABLE_READ_TYPES.fetch(node.parent.type), node.parent.name, nil)
          end
        end

        def constant_assignment_name
          [ constant_name_of(node.parent.children.first), node.parent.name ].compact.join("::")
        end

        def method_domain
          domain.identity
        end

        def domain
          @domain ||= RuboCop::Callbacksystems::Methods::Domain.new(node)
        end

        def returning_method_home
          Home.new(:method, returning_method_name, method_domain) if returning_method_name
        end

        def returning_method_name
          enclosing_method.method_name if returned?
        end

        def returned?
          enclosing_method.present? && (node.parent.return_type? || closes_its_method?)
        end

        def enclosing_method
          @enclosing_method ||= enclosing_method_of(node)
        end

        def closes_its_method?
          last_statement_in(enclosing_method.body).equal?(node)
        end

        def serialization_output?
          SERIALIZATION_METHODS.include?(returning_method_name)
        end
    end
end
