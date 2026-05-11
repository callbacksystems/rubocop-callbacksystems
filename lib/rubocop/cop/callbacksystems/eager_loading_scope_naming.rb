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
class RuboCop::Cop::Callbacksystems::EagerLoadingScopeNaming < RuboCop::Cop::Callbacksystems::Base
  # @!method scope_definition(node)
  def_node_matcher :scope_definition, <<~PATTERN
    (send nil? :scope (sym $_name) $_body ...)
  PATTERN

  PREFIX_MESSAGE = "Eager loading scopes should follow `with_*` convention. Rename `%<name>s` to `with_%<association>s`."
  ACTION_MESSAGE = "Scope name `%<name>s` contains controller action `%<action>s`. Use a more descriptive name."
  GENERIC_MESSAGE = "Scope name `%<name>s` contains generic term `%<term>s`. Use a more specific name like `with_%<association>s`."

  def on_send(node)
    scope_definition(node) do |name, body|
      next unless (association = ScopeBody.new(body).eager_loading_association)

      ScopeNameChecker.new(name, association).offenses.each do |message|
        add_offense(node.first_argument, message: message)
      end
    end
  end

  alias on_csend on_send

  private
    class ScopeNameChecker
      include RuboCop::Callbacksystems::Helpers

      GENERIC_TERMS = %w[association associations relation relations].freeze

      def initialize(name, association)
        @name = name
        @association = association
        @name_parts = name.to_s.split("_")
      end

      def offenses
        [
          (format(PREFIX_MESSAGE, name: name, association: association) unless name.to_s.start_with?("with_")),
          (format(ACTION_MESSAGE, name: name, action: controller_action) if controller_action),
          (format(GENERIC_MESSAGE, name: name, term: generic_term, association: association) if generic_term)
        ].compact
      end

      private
        attr_reader :name, :association, :name_parts

        def controller_action
          STANDARD_CONTROLLER_ACTIONS.find { name_parts.include?(it.to_s) }
        end

        def generic_term
          GENERIC_TERMS.find { name_parts.include?(it) }
        end
    end

    class ScopeBody
      include RuboCop::Callbacksystems::Helpers

      attr_reader :body

      def initialize(body)
        @body = body
      end

      def eager_loading_association
        eager_load_node = scope_body&.each_descendant(:send)&.find { EAGER_LOADING_METHODS.include?(it.method_name) }
        association_name_for(eager_load_node) if eager_load_node
      end

      private
        def scope_body
          block_body || lambda_body
        end

        def block_body
          body if any_block_type?(body)
        end

        def lambda_body
          body.children.last if body&.send_type? && body.method?(:lambda)
        end

        def association_name_for(eager_load_node)
          first_arg = eager_load_node.first_argument
          if first_arg&.sym_type?
            first_arg.value.to_s
          elsif first_arg
            first_arg.source
          end
        end
    end
end
