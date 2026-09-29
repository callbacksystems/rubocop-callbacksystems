# Detects array subtraction and record-ID exclusions that can use `excluding`.
# The method names the excluded object directly, instead of wrapping it in a
# throwaway array or spelling out its database identifier.
#
# `excluding` flattens the arguments it receives, and Enumerable supplies a
# version whose result is an Array. Automatic correction therefore needs
# positive evidence that the receiver is an Array and the element is not one;
# an unknown value is still reported for a human who knows its domain.
#
# Relation exclusions are suggestions for human review. Active Record requires
# an instance of the relation's model and excludes its primary key, which may
# differ from the `id` column. Visible mismatches and custom primary keys are
# left alone, as are safe navigation and compound negative conditions.
#
# @example
#   # bad
#   users - [admin]
#   items - [first_item]
#   User.where.not(id: user.id)
#
#   # good
#   users.excluding(admin)
#   items.excluding(first_item)
#   User.excluding(user)
#
class RuboCop::Cop::Callbacksystems::PreferExcluding < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  def on_send(node)
    report Subtraction.new(node, source_comments:)
    report RecordExclusion.new(node, source_root: processed_source.ast)
  end

  alias on_csend on_send

  private
    class Subtraction
      include RuboCop::Callbacksystems::Helpers
      extend RuboCop::AST::NodePattern::Macros

      MESSAGE = "Use `excluding` instead of `- [element]`."
      NON_ARRAY_LITERAL_TYPES =
        %i[ complex dstr dsym erange false float hash int irange nil rational regexp str sym true ]

      # @!method single_element_subtraction(node)
      def_node_matcher :single_element_subtraction, <<~PATTERN
        (call $_ :- (array $_element))
      PATTERN

      def initialize(node, source_comments:)
        @node = node
        @source_comments = source_comments
        @receiver, @element = single_element_subtraction(node)
      end

      def offense
        if receiver
          RuboCop::Callbacksystems::Offense.new(node, MESSAGE, correcting: correction_equivalent?) { correct(it) }
        end
      end

      private
        attr_reader :node, :source_comments, :receiver, :element

        def correction_equivalent?
          array_value?(receiver) && non_array_value?(element) && standalone_element_source? &&
            !source_comments.any_within?(node)
        end

        def array_value?(candidate)
          reads_as_array?(candidate) || adjacent_assigned_value_of(candidate)&.then { reads_as_array?(it) }
        end

        def adjacent_assigned_value_of(candidate)
          AdjacentAssignment.new(candidate, beside: node).value
        end

        def non_array_value?(candidate)
          known_non_array?(candidate) || adjacent_assigned_value_of(candidate)&.then { known_non_array?(it) }
        end

        def known_non_array?(candidate)
          NON_ARRAY_LITERAL_TYPES.include?(candidate.type) ||
            (candidate.begin_type? && candidate.children.one? && known_non_array?(candidate.children.first))
        end

        def standalone_element_source?
          !element.parent.percent_literal? || element.type?(:str, :sym)
        end

        def correct(corrector)
          corrector.replace(node, "#{receiver.source}#{call_operator}excluding(#{argument})")
        end

        def call_operator
          node.csend_type? ? "&." : "."
        end

        # Inside a percent literal an element is written bare, so its source alone would not survive on its own.
        def argument
          element.parent.percent_literal? ? element.value.inspect : element.source
        end
    end

    class RecordExclusion
      include RuboCop::Callbacksystems::Helpers
      extend RuboCop::AST::NodePattern::Macros

      MESSAGE = "Consider `excluding(%<record>s)` when the record belongs to this relation's model " \
        "and its primary key is `id`."

      # @!method record_exclusion(node)
      def_node_matcher :record_exclusion, <<~PATTERN
        (send (send $_relation :where) :not (hash (pair {(sym :id) (str "id")} (send $_record :id))))
      PATTERN

      def initialize(node, source_root:)
        @node = node
        @source_root = source_root
        @relation, @record = record_exclusion(node)
      end

      def offense
        if record && applicable?
          RuboCop::Callbacksystems::Offense.new(node, format(MESSAGE, record: record.source))
        end
      end

      private
        attr_reader :node, :source_root, :relation, :record

        def applicable?
          node.each_node(:csend).none? && !non_record_value? && !different_models? && !custom_primary_key?
        end

        def non_record_value?
          record_value.literal? || record_value.const_type? || relation&.literal?
        end

        def record_value
          @record_value ||= AdjacentAssignment.new(record, beside: node).value || record
        end

        def different_models?
          relation_model && record_model && relation_model != record_model
        end

        def relation_model
          @relation_model ||= model_name_of(relation)
        end

        def model_name_of(candidate)
          candidate = candidate.receiver while candidate&.call_type?
          constant_name_of(candidate)&.delete_prefix("::")
        end

        def record_model
          @record_model ||= model_name_of(record_value)
        end

        def custom_primary_key?
          source_root.each_node(:send, :defs).any? do |candidate|
            if candidate.defs_type?
              candidate.method?(:primary_key)
            else
              candidate.method?(:primary_key=) && !default_primary_key?(candidate.first_argument)
            end
          end
        end

        def default_primary_key?(value)
          value.type?(:str, :sym) && value.value.to_s == "id"
        end
    end

    # A local's immediately preceding assignment, shared by both forms of exclusion.
    class AdjacentAssignment
      def initialize(variable, beside:)
        @variable = variable
        @node = beside
      end

      def value
        if variable.lvar_type? && matching_assignment?
          previous.expression
        end
      end

      private
        attr_reader :variable, :node

        def matching_assignment?
          previous&.lvasgn_type? && previous.name == variable.name
        end

        def previous
          @previous ||= statement_containing_node&.left_sibling
        end

        def statement_containing_node
          @statement_containing_node ||= [ node, *node.each_ancestor ].find { it.parent&.type?(:begin, :kwbegin) }
        end
    end
end
