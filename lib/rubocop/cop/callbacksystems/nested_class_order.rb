# Orders the nested classes of a body by reference: one that names another reads
# before the one it names, the way `MethodInvocationOrder` reads a caller before
# its callees.
#
# Only a class or module carrying a body counts. A constant built in a line
# (`Row = Data.define(:name)`, `Error = Class.new(StandardError)`) is a
# declaration, and `BodyOrder` reads those with the values at the top.
#
# Where the nested classes sit is `BodyOrder`'s business, which keeps them last.
# This one only orders them among themselves, inside the run they already form.
#
# @example
#   # bad - Row names Cell, so Row reads first
#   class Report
#     class Cell
#       def value; end
#     end
#
#     class Row
#       def cells
#         [ Cell.new ]
#       end
#     end
#   end
#
#   # good
#   class Report
#     class Row
#       def cells
#         [ Cell.new ]
#       end
#     end
#
#     class Cell
#       def value; end
#     end
#   end
#
class RuboCop::Cop::Callbacksystems::NestedClassOrder < RuboCop::Cop::Callbacksystems::Base
  include RuboCop::Callbacksystems::ProjectIndex::Support
  extend RuboCop::Cop::AutoCorrector

  def on_new_investigation
    report_each Bodies.new(processed_source, constant_references:) if project_index_reliable?
  end

  private
    def constant_references
      RuboCop::Callbacksystems::ProjectIndex::ConstantReferences.for(project_index).within(processed_source)
    end

    class Bodies
      include RuboCop::Callbacksystems::Helpers

      def initialize(processed_source, constant_references:)
        @processed_source = processed_source
        @constant_references = constant_references
      end

      def each_offense(&block)
        runs.each do |run|
          NestedClasses.new(run, processed_source, constant_references:, permit:).each_offense(&block)
        end
      end

      private
        attr_reader :processed_source, :constant_references

        def runs
          @runs ||= definition_nodes_in(processed_source.ast).flat_map { runs_of(it) }.select(&:many?)
        end

        def runs_of(node)
          runs_in(node.body) { declared_class?(it) }
        end

        # A constant built from a builder stays out, since `BodyOrder` already places it among the values or the nested
        # classes.
        def declared_class?(node)
          node.type?(:class, :module) && node.body.present?
        end

        def permit
          @permit ||= RuboCop::Callbacksystems::Autocorrection::RewritePermit.new
        end
    end

    # One run of nested classes written together, read for the first that sits before a class naming it.
    class NestedClasses
      MESSAGE = "Class `%<expected>s` should be defined before `%<actual>s`, since it names it."

      def initialize(nodes, processed_source, constant_references:, permit:)
        @nodes = nodes
        @processed_source = processed_source
        @constant_references = constant_references
        @permit = permit
      end

      def each_offense
        yield offense if reportable?
      end

      private
        attr_reader :nodes, :processed_source, :constant_references, :permit
        delegate :rewrite, to: :statement_run, private: true

        def reportable?
          analyzable? && ordered_safely?
        end

        # Reopening gives one declaration several load positions, so no single reference order can place it truthfully.
        def analyzable?
          classes.all?(&:uniquely_declared?) && identities.uniq.size == identities.size
        end

        def classes
          @classes ||= nodes.map { NestedClass.new(it, processed_source, constant_references:) }
        end

        def identities
          @identities ||= classes.map(&:identity)
        end

        def ordered_safely?
          divergence.found? && load_order_kept?
        end

        def divergence
          @divergence ||= RuboCop::Callbacksystems::ClassStructure::Divergence.new(identities, from: canonical_order)
        end

        def canonical_order
          @canonical_order ||= RuboCop::Callbacksystems::ClassStructure::ReferenceOrder.new(seeds, reference_graph).to_a
        end

        def seeds
          identities.reject { referenced.include?(it) } + identities
        end

        def referenced
          @referenced ||= reference_graph.values.flatten.to_set
        end

        def reference_graph
          @reference_graph ||= graph_of(:reads)
        end

        def graph_of(reading)
          classes.to_h { [ it.identity, it.public_send(reading).intersection(identities) ] }
        end

        # A superclass or a name read outside a method runs as the body loads, so an order breaking one is refused.
        def load_order_kept?
          dependency_graph.all? { |name, required| required.all? { loaded_before?(dependency: it, dependent: name) } }
        end

        def dependency_graph
          @dependency_graph ||= graph_of(:dependencies)
        end

        def loaded_before?(dependency:, dependent:)
          canonical_positions.fetch(dependency) < canonical_positions.fetch(dependent)
        end

        def canonical_positions
          @canonical_positions ||= canonical_order.each_with_index.to_h
        end

        def offense
          RuboCop::Callbacksystems::Offense.new(nodes[divergence.index], message,
            correcting: correctable?) { rewrite(it) }
        end

        def message
          format(MESSAGE, expected: name_of(divergence.expected), actual: name_of(divergence.actual))
        end

        def name_of(identity)
          classes_by_identity.fetch(identity).name
        end

        def classes_by_identity
          @classes_by_identity ||= classes.index_by(&:identity)
        end

        def correctable?
          uninterrupted? && statement_run.reorderable? && permit.claim
        end

        # A comment unattached to either class is an intentional boundary, not source for a sortable run.
        def uninterrupted?
          classes.each_cons(2).none? { |above, below| above.range.end.join(below.range.begin).source.strip.present? }
        end

        def statement_run
          @statement_run ||= RuboCop::Callbacksystems::ClassStructure::StatementRun.new \
            classes, order: canonical_order, &:identity
        end
    end

    class NestedClass
      include RuboCop::Callbacksystems::Helpers

      delegate :range, :source, :contains_tooling_comment?, to: :block

      def initialize(node, processed_source, constant_references:)
        @node = node
        @processed_source = processed_source
        @constant_references = constant_references
      end

      def reads
        referenced_identities_of(constants.select { enclosing_method_of(it).present? })
      end

      def name
        node.identifier.short_name
      end

      def identity
        declaration&.name
      end

      def uniquely_declared?
        declaration.is_a?(Rubydex::Namespace) && declaration.definitions.one?
      end

      def dependencies
        referenced_identities_of(superclass_constants + constants.reject { enclosing_method_of(it).present? })
      end

      private
        attr_reader :node, :processed_source, :constant_references

        def block
          @block ||= RuboCop::Callbacksystems::Source::StatementWithComments.new(node, processed_source)
        end

        def referenced_identities_of(found)
          found.filter_map { constant_references.referenced_declaration_for(it)&.name }.uniq.excluding(identity)
        end

        def constants
          @constants ||= node.each_descendant(:const).to_a
        end

        def declaration
          @declaration ||= constant_references.declaration_named(node.identifier.const_name, beside: node.identifier)
        end

        def superclass_constants
          node.class_type? && node.parent_class ? node.parent_class.each_node(:const).to_a : []
        end
    end
end
