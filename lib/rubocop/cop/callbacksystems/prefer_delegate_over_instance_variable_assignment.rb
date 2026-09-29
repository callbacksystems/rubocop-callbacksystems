# Detects `@x = receiver.x` style assignments inside `initialize` that mirror
# a method call. These eager assignments are better expressed as `delegate`
# declarations: they read declaratively, avoid duplicating the name, and stop
# inviting bigger refactors (the very anti-pattern flagged by
# `NoRedundantWrapperMethod` and `NoAnemicDelegation`).
#
# Only assignments where the variable name matches the called method name are
# flagged, and only when the receiver itself is also assigned to a variable of
# the same name in the same `initialize` (so the receiver is reachable via
# `attr_reader` from the surrounding class).
#
# @example
#   # bad - eager assignment that mirrors `node.body`
#   def initialize(node)
#     @node = node
#     @body = node.body
#   end
#
#   private
#     attr_reader :node, :body
#
#   # good - declare the delegation
#   def initialize(node)
#     @node = node
#   end
#
#   private
#     attr_reader :node
#     delegate :body, to: :node, private: true
#
#   # ok - the assignment transforms the value (different name from the call)
#   def initialize(name)
#     @name = name
#     @name_parts = name.split("_")
#   end
#
class RuboCop::Cop::Callbacksystems::PreferDelegateOverInstanceVariableAssignment < RuboCop::Cop::Callbacksystems::Base
  def on_ivasgn(node)
    report Assignment.new(node)
  end

  private
    class Assignment
      extend RuboCop::AST::NodePattern::Macros
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Replace `@%<name>s = %<receiver>s.%<name>s` with `delegate :%<name>s, to: :%<receiver>s`."

      # @!method mirroring_assignment?(node)
      def_node_matcher :mirroring_assignment?, <<~PATTERN
        (ivasgn $_ (send (lvar $_) $_))
      PATTERN

      # @!method receiver_assignment?(node, variable_name, lvar_name)
      def_node_matcher :receiver_assignment?, <<~PATTERN
        (ivasgn %1 (lvar %2))
      PATTERN

      def initialize(node)
        @node = node
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(node, message) if mirroring_delegation?
      end

      private
        attr_reader :node

        def mirroring_delegation?
          variable_name && variable_matches_method? && stable_initialization?
        end

        def variable_name
          captures&.first
        end

        def captures
          @captures ||= mirroring_assignment?(node)
        end

        def variable_matches_method?
          name_without_sigil(variable_name).to_sym == method_name
        end

        def method_name
          captures.third
        end

        def stable_initialization?
          direct_receiver_pair? && stable_state?
        end

        def direct_receiver_pair?
          direct_initialize_assignment? && receiver_assignment_precedes?
        end

        def direct_initialize_assignment?
          initialize_method && direct_statements.any? { it.equal?(node) }
        end

        def initialize_method
          @initialize_method ||= node.each_ancestor(:any_def).find { it.method?(:initialize) }
        end

        def direct_statements
          @direct_statements ||= statements_in(initialize_method.body)
        end

        def receiver_assignment_precedes?
          receiver_assignment && receiver_assignment.source_range.begin_pos < node.source_range.begin_pos
        end

        def receiver_assignment
          @receiver_assignment ||= direct_statements.find do |statement|
            receiver_assignment?(statement, :"@#{receiver_name}", receiver_name)
          end
        end

        def receiver_name
          captures.second
        end

        def stable_state?
          receiver_local_stable? && instance_state_stable?
        end

        def receiver_local_stable?
          receiver_rebindings.none? { between_receiver_and_mirror?(it) }
        end

        def receiver_rebindings
          nodes_in(initialize_method.body, :lvasgn, :match_var).select { variable_name_of(it) == receiver_name }
        end

        def between_receiver_and_mirror?(write)
          write.source_range.begin_pos.between?(receiver_assignment.source_range.end_pos, node.source_range.begin_pos)
        end

        def instance_state_stable?
          sole_instance_write?(receiver_variable_name, receiver_assignment) && sole_instance_write?(variable_name, node)
        end

        def sole_instance_write?(name, expected)
          instance_writes_to(name).then { it.one? && it.first.equal?(expected) }
        end

        def instance_writes_to(name)
          nodes_in(state_scope&.body, :ivasgn).select { it.name == name && same_instance?(it) }
        end

        def state_scope
          state_domain.container
        end

        def state_domain
          @state_domain ||= RuboCop::Callbacksystems::Methods::Domain.new(node)
        end

        def same_instance?(write)
          domain = RuboCop::Callbacksystems::Methods::Domain.new(write)

          domain.container.equal?(state_scope) && domain.identity == state_domain.identity &&
            self_preserved_between?(write, boundary: enclosing_method_of(write) || state_scope)
        end

        def receiver_variable_name
          :"@#{receiver_name}"
        end

        def message
          format(MESSAGE, name: method_name, receiver: receiver_name)
        end
    end
end
