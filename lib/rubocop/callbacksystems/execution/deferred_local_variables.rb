# Local variables captured or reassigned by callable bodies that execute after their surrounding expression.
class RuboCop::Callbacksystems::Execution::DeferredLocalVariables
  include RuboCop::Callbacksystems::Helpers

  delegate :include?, :exclude?, to: :names

  def initialize(body)
    @body = body
  end

  private
    attr_reader :body

    def names
      @names ||= Traversal.new(body).to_set.freeze
    end

    # An iterative lexical walk keeps bindings paired with entry and exit while deferred bodies are visited.
    class Traversal
      include Enumerable
      include RuboCop::Callbacksystems::Helpers

      def initialize(body)
        @context = Context.new(Visit.new(body, false))
      end

      def each
        if block_given?
          advance { yield it }
        else
          to_enum(__method__)
        end
      end

      private
        attr_reader :context

        def advance
          context.next_event.perform(context) { yield it } while context.pending?
        end
    end

    class Context
      def initialize(first_event)
        @pending = [ first_event ]
        @binding_counts = Hash.new(0)
      end

      def pending?
        pending.any?
      end

      def next_event
        pending.pop
      end

      def queue(*events)
        pending.concat(events.reverse)
      end

      def enter(names)
        names.each { binding_counts[it] += 1 }
      end

      def leave(names)
        names.each { binding_counts[it] -= 1 }
      end

      def bound?(name)
        binding_counts[name].positive?
      end

      private
        attr_reader :pending, :binding_counts
    end

    class Visit < Data.define(:node, :deferred)
      include RuboCop::Callbacksystems::Helpers

      def perform(context)
        if node
          if any_block_type?(node)
            queue_block(context)
          elsif lexical_definition?(node)
            context.queue(*input_visits)
          else
            yield variable_name_of(node) if captured_variable?(context)
            queue_children(context)
          end
        end
      end

      private
        def queue_block(context)
          bindings = binding_names
          body_deferred = deferred || deferred_callable_block?(node) || method_definition_block?(node)

          context.queue \
            *input_visits,
            EnterBindings.new(bindings),
            self.class.new(argument_node, body_deferred),
            self.class.new(node.body, body_deferred),
            LeaveBindings.new(bindings)
        end

        def binding_names
          node.argument_list.filter_map(&:name)
        end

        def input_visits
          immediate_inputs_of(node).map { self.class.new(it, deferred) }
        end

        def argument_node
          node.arguments if node.arguments.respond_to?(:type)
        end

        def captured_variable?(context)
          deferred && node.type?(:lvar, :lvasgn, :match_var) && !context.bound?(variable_name_of(node))
        end

        def queue_children(context)
          context.queue(*node.each_child_node.map { self.class.new(it, deferred) })
        end
    end

    class EnterBindings < Data.define(:names)
      def perform(context)
        context.enter(names)
      end
    end

    class LeaveBindings < Data.define(:names)
      def perform(context)
        context.leave(names)
      end
    end
end
