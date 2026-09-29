# Detects a lambda or proc assigned to a local variable inside a method when
# its body reads nothing from that method. A closure that closes over no
# local and no parameter is a method in disguise: giving it a name of its own
# lets it be read and tested alone, and keeps the enclosing method to its
# job. Instance variables, methods on `self` and constants do not count as
# captures, since a method reads those too, and neither do the closure's own
# parameters and locals.
#
# A closure that reads or reassigns a local or a parameter of the method is
# left alone, since that capture is the point of the closure. So is one that
# yields to the method's block or calls `super`, one defined outside a method,
# such as a scope or a callback, and one not held in a local, whose shape
# other cops judge.
#
# @example
#   # bad - the lambda reads nothing from `total`
#   def total(orders)
#     price_of = ->(order) { order.quantity * order.unit_price }
#     orders.sum { price_of.call(it) }
#   end
#
#   # good - a method of its own
#   def total(orders)
#     orders.sum { price_of(it) }
#   end
#
#   def price_of(order)
#     order.quantity * order.unit_price
#   end
#
#   # good - the lambda closes over `rate`
#   def total(orders, rate)
#     price_of = ->(order) { order.quantity * rate }
#     orders.sum { price_of.call(it) }
#   end
#
class RuboCop::Cop::Callbacksystems::PreferMethodOverLambda < RuboCop::Cop::Callbacksystems::Base
  def on_lvasgn(node)
    node.each_ancestor(:any_def, :class, :module, :sclass).first&.then do |definition|
      report HeldClosure.new(node, method_node: definition) if definition.any_def_type?
    end
  end

  private
    # A local assignment inside a method, read as a closure against the names that method binds around it.
    class HeldClosure
      extend RuboCop::AST::NodePattern::Macros
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "`%<name>s` captures nothing from `%<method>s`, so it can be a method of its own."

      # @!method closure?(node)
      def_node_matcher :closure?, <<~PATTERN
        (any_block {(lambda) (send nil? {:lambda :proc}) (send (const {nil? cbase} :Proc) :new)} ...)
      PATTERN

      def initialize(node, method_node:)
        @node = node
        @method_node = method_node
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(node, message) if closure?(closure) && captures_nothing?
      end

      private
        attr_reader :node, :method_node

        def closure
          node.expression
        end

        def captures_nothing?
          captured_uses.none? && !depends_on_method_context?
        end

        def captured_uses
          LocalVariables.used_in(closure).select do |use|
            method_names.include?(use.name) && !bound_within_closure?(use)
          end
        end

        # The closure's own name is left out so that a recursive call counts as no capture.
        def method_names
          @method_names ||= bindings_around_closure.filter_map(&:name).excluding(node.name)
        end

        def bindings_around_closure
          LocalVariables.bound_in(method_node).select { binding_visible_around_closure?(it) }
        end

        def binding_visible_around_closure?(binding)
          binding.node.source_range.begin_pos < closure.source_range.begin_pos &&
            binding_scopes.include?(lexical_scope_of(binding.node))
        end

        def binding_scopes
          @binding_scopes ||= closure.each_ancestor(:any_block, :any_def)
            .take_while { !it.equal?(method_node) }
            .push(method_node)
        end

        def lexical_scope_of(binding)
          binding.each_ancestor(:any_def, :any_block, :class, :module, :sclass).first
        end

        def bound_within_closure?(use)
          blocks_from(use).any? { block_binds?(it, use.name) }
        end

        def blocks_from(use)
          use.node.each_ancestor(:any_block).take_while { !it.equal?(closure) }.push(closure)
        end

        def block_binds?(block, name)
          block.argument_list.any? { it.name == name }
        end

        def depends_on_method_context?
          nodes_in(closure, :yield, :super, :zsuper, :return, :break, :next, :redo, :retry).any? ||
            nodes_in(closure, :send, :csend).any? { ContextualCall.new(it).contextual? }
        end

        def message
          format(MESSAGE, name: node.name, method: method_node.method_name)
        end

        class ContextualCall
          include RuboCop::Callbacksystems::Helpers

          CONTEXTUAL_METHODS = %i[ binding block_given? __method__ __callee__ eval local_variables ]
          REFLECTIVE_METHODS = %i[ send __send__ method ]
          STRING_EVAL_METHODS = %i[ instance_eval class_eval module_eval ]

          def initialize(node)
            @node = node
          end

          def contextual?
            direct? || reflective? || string_eval?
          end

          private
            attr_reader :node

            def direct?
              contextual_receiver? && CONTEXTUAL_METHODS.include?(node.method_name)
            end

            def contextual_receiver?
              call_on_self?(node) || (core_constant?(node.receiver) && node.receiver.short_name == :Kernel)
            end

            def reflective?
              node.first_argument&.then do |argument|
                REFLECTIVE_METHODS.include?(node.method_name) &&
                  (!argument.type?(:sym, :str) || contextual_reflection?(argument.value.to_sym))
              end
            end

            def contextual_reflection?(method_name)
              STRING_EVAL_METHODS.include?(method_name) ||
                (contextual_receiver? && CONTEXTUAL_METHODS.include?(method_name))
            end

            def string_eval?
              STRING_EVAL_METHODS.include?(node.method_name) && node.arguments.any?
            end
        end

        class LocalVariables
          include RuboCop::Callbacksystems::Helpers

          BINDING_TYPES = %i[ arg optarg restarg kwarg kwoptarg kwrestarg blockarg shadowarg lvasgn match_var ]
          USE_TYPES = %i[ lvar lvasgn match_var ]
          Occurrence = Data.define(:node, :name)

          class << self
            def bound_in(tree)
              new(tree, types: BINDING_TYPES).to_a
            end

            def used_in(tree)
              new(tree, types: USE_TYPES).to_a
            end
          end

          def initialize(tree, types:)
            @tree = tree
            @types = types
          end

          def to_a
            node_occurrences + regexp_occurrences
          end

          private
            attr_reader :tree, :types

            def node_occurrences
              nodes_in(tree, *types).map { Occurrence.new(it, variable_name_of(it)) }
            end

            def regexp_occurrences
              nodes_in(tree, :match_with_lvasgn).flat_map do |match|
                match.children.first.to_regexp.named_captures.each_key.map { Occurrence.new(match, it.to_sym) }
              end
            end
        end
    end
end
