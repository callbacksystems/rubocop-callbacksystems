# Ensures eager loading scopes follow naming conventions.
# - Must use `with_*` prefix
# - Must not contain controller action names (index, show, etc.)
# - Must not contain generic terms (associations, relations)
#
# @example
#   # bad - missing with_ prefix
#   scope :including_posts, -> { includes(:posts) }
#
#   # bad - contains controller action
#   scope :with_show_data, -> { includes(:items) }
#
#   # bad - contains generic term
#   scope :with_associations, -> { includes(:items) }
#
#   # good
#   scope :with_posts, -> { includes(:posts) }
#   scope :with_line_items, -> { includes(:line_items) }
#
class RuboCop::Cop::Callbacksystems::EagerLoadingScopeNaming < RuboCop::Cop::Base
  EAGER_LOADING_METHODS = %i[preload eager_load includes].freeze

  def_node_matcher :scope_definition, <<~PATTERN
    (send nil? :scope (sym $_name) $_body ...)
  PATTERN

  def on_send(node)
    scope_definition(node) do |name, body|
      association = ScopeBody.new(body).eager_loading_association
      next unless association

      ScopeNameChecker.new(node, name, association, self).check
    end
  end

  private
    class ScopeNameChecker
      CONTROLLER_ACTIONS = %w[index show new create edit update destroy].freeze
      GENERIC_TERMS = %w[association associations relation relations].freeze

      def initialize(node, name, association, cop)
        @node = node
        @name = name
        @association = association
        @cop = cop
        @name_parts = name.to_s.split("_")
      end

      def check
        check_with_prefix
        check_controller_actions
        check_generic_terms
      end

      private
        attr_reader :node, :name, :association, :cop, :name_parts

        def check_with_prefix
          return if name.to_s.start_with?("with_")

          message = "Eager loading scopes should follow `with_*` convention. Rename `#{name}` to `with_#{association}`."
          cop.add_offense(node.first_argument, message: message)
        end

        def check_controller_actions
          found = CONTROLLER_ACTIONS.find { |action| name_parts.include?(action) }
          add_controller_action_offense(found) if found
        end

        def check_generic_terms
          found = GENERIC_TERMS.find { |term| name_parts.include?(term) }
          add_generic_term_offense(found) if found
        end

        def add_controller_action_offense(action)
          message = "Scope name `#{name}` contains controller action `#{action}`. Use a more descriptive name."
          cop.add_offense(node.first_argument, message: message)
        end

        def add_generic_term_offense(term)
          message = "Scope name `#{name}` contains generic term `#{term}`. Use a more specific name like `with_#{association}`."
          cop.add_offense(node.first_argument, message: message)
        end
    end

    class ScopeBody
      attr_reader :body

      def initialize(body)
        @body = body
      end

      def eager_loading_association
        eager_load_node = scope_body&.each_descendant(:send)&.find { |send_node| EAGER_LOADING_METHODS.include?(send_node.method_name) }
        association_name_for(eager_load_node) if eager_load_node
      end

      private
        def scope_body
          block_body || lambda_body
        end

        def block_body
          body if body&.block_type? || body&.numblock_type?
        end

        def lambda_body
          body.children.last if body&.send_type? && body.method_name == :lambda
        end

        def association_name_for(eager_load_node)
          first_arg = eager_load_node.arguments.first
          if first_arg&.sym_type?
            first_arg.value.to_s
          elsif first_arg
            first_arg.source
          end
        end
    end
end
