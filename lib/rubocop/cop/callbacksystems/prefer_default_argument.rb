# Detects a parameter given its fallback value at the top of the method. A
# `||=` or a `nil?` guard opening the body makes the reader work out what the
# parameter really is, where a default in the signature says it right where the
# parameter is declared, so the body starts with the work.
#
# The cop recommends the change for a positional parameter and a keyword
# declared as `name: nil`. It leaves a required keyword alone, since a default
# would change what callers must pass, as well as a fallback reading a parameter
# declared to its right, which a default cannot see. Only the run of fallbacks
# opening the body counts: one that follows other statements may depend on them.
#
# The offense has no automatic correction. A default only runs when an argument
# is omitted, while these fallbacks also run for an explicit `nil` or `false`;
# making a required positional parameter optional changes its observable arity
# too. Choosing the new calling contract belongs to the author.
#
# @example
#   # bad
#   def deliver(recipients)
#     recipients ||= [ owner ]
#     recipients.each { mail(it) }
#   end
#
#   # bad
#   def deliver(recipients: nil)
#     recipients = [ owner ] if recipients.nil?
#     recipients.each { mail(it) }
#   end
#
#   # good
#   def deliver(recipients = [ owner ])
#     recipients.each { mail(it) }
#   end
#
#   # good
#   def deliver(recipients: [ owner ])
#     recipients.each { mail(it) }
#   end
#
#   # good - a default cannot read a parameter to its right
#   def deliver(recipients, sender)
#     recipients ||= [ sender ]
#     recipients.each { mail(it) }
#   end
#
class RuboCop::Cop::Callbacksystems::PreferDefaultArgument < RuboCop::Cop::Callbacksystems::Base
  def on_def(node)
    report_each LeadingFallbacks.new(node)
  end

  alias on_defs on_def

  private
    # The fallbacks opening a method body, one per parameter, narrowed to those expressible as a signature default.
    class LeadingFallbacks
      include RuboCop::Callbacksystems::Helpers

      def initialize(method_node)
        @method_node = method_node
      end

      def each_offense
        reportable.each { yield it.offense } if followed_by_work?
      end

      private
        attr_reader :method_node

        def followed_by_work?
          statements.size > leading.size
        end

        def statements
          statements_in(method_node.body)
        end

        def leading
          @leading ||= statements.map { Fallback.new(it, method_node) }.take_while(&:fallback?).uniq(&:name)
        end

        # Ruby allows one group of optional positional parameters, so a recommendation must not open a second one.
        def reportable
          optional_group_stays_contiguous? ? candidates : candidates.select(&:keyword?)
        end

        def optional_group_stays_contiguous?
          optional_runs.size <= 1
        end

        def optional_runs
          positional_parameters
            .chunk_while { |left, right| optional_with_candidate?(left) == optional_with_candidate?(right) }
            .select { optional_with_candidate?(it.first) }
        end

        def positional_parameters
          method_node.arguments.select { it.type?(:arg, :optarg) }
        end

        def optional_with_candidate?(parameter)
          parameter.optarg_type? || candidates.any? { it.parameter.equal?(parameter) }
        end

        def candidates
          @candidates ||= leading.select(&:reportable?)
        end
    end

    class Fallback
      include RuboCop::Callbacksystems::Helpers
      extend RuboCop::AST::NodePattern::Macros

      MESSAGE = "Give `%<name>s` its default in the signature instead of a fallback in the body."

      # @!method fallback_of(node)
      def_node_matcher :fallback_of, <<~PATTERN
        {
          (or_asgn (lvasgn $_name) $_value)
          (if (send (lvar $_name) :nil?) (lvasgn _name $_value) nil?)
          (if (lvar $_name) nil? (lvasgn _name $_value))
        }
      PATTERN

      def initialize(statement, method_node)
        @statement = statement
        @method_node = method_node
      end

      def fallback?
        parameter.present?
      end

      def parameter
        @parameter ||= named_parameters.find { it.name == name } if name
      end

      def name
        captures&.first
      end

      def keyword?
        parameter.kwoptarg_type?
      end

      def reportable?
        defaultable? && value.single_line? && !carries_heredoc?(value) && !reads_parameter_from_itself_on? &&
          alone_on_its_lines?
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(statement, format(MESSAGE, name:))
      end

      private
        attr_reader :statement, :method_node

        def captures
          @captures ||= fallback_of(statement)
        end

        def named_parameters
          method_node.arguments.reject(&:mlhs_type?)
        end

        def defaultable?
          (parameter.arg_type? && !positional_parameter_after_rest?) ||
            (keyword? && parameter.default_value.nil_type?)
        end

        def positional_parameter_after_rest?
          method_node.arguments.take_while { !it.equal?(parameter) }.any?(&:restarg_type?)
        end

        def value
          captures.second
        end

        def reads_parameter_from_itself_on?
          nodes_in(value, :lvar).any? do |read|
            parameter_names_from_itself_on.include?(read.name) &&
              !name_rebound_between?(read.name, node: read, boundary: method_node)
          end
        end

        def parameter_names_from_itself_on
          method_node.arguments.drop_while { !it.equal?(parameter) }.flat_map { ParameterNames.new(it).to_a }
        end

        def alone_on_its_lines?
          statement.first_line > method_node.first_line && statement.last_line < next_code_line
        end

        def next_code_line
          statement.right_sibling.first_line
        end
    end

    # Names introduced by one argument, including the leaves of a destructured positional argument.
    class ParameterNames
      include Enumerable

      def initialize(parameter)
        @parameter = parameter
      end

      def each
        if block_given?
          pending = [ parameter ]
          until pending.empty?
            current = pending.pop
            if current.mlhs_type?
              pending.concat(current.each_child_node.to_a.reverse)
            elsif current.respond_to?(:name) && current.name
              yield current.name
            end
          end
        else
          to_enum(__method__)
        end
      end

      private
        attr_reader :parameter
    end
end
