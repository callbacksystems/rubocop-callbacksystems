# Ensures eager loading scopes follow naming conventions. - Must use `with_*` prefix - Must not contain controller
# action names (index, show, etc.) - Must not contain generic terms (associations, relations)
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

      ScopeNameChecker.new(node.first_argument, name, association).each_offense do |offense_node, message|
        add_offense(offense_node, message: message)
      end
    end
  end

  alias on_csend on_send

  private
    class ScopeNameChecker
      include RuboCop::Callbacksystems::Helpers

      GENERIC_TERMS = %w[association associations relation relations].freeze

      def initialize(offense_node, name, association)
        @offense_node = offense_node
        @name = name
        @association = association
        @name_parts = name.to_s.split("_")
      end

      def each_offense(&block)
        if block
          messages.each { yield offense_node, it }
        else
          to_enum(__method__)
        end
      end

      private
        attr_reader :offense_node, :name, :association, :name_parts

        def messages
          [
            (format(PREFIX_MESSAGE, name: name, association: association) unless name.to_s.start_with?("with_")),
            (format(ACTION_MESSAGE, name: name, action: controller_action) if controller_action),
            (format(GENERIC_MESSAGE, name: name, term: generic_term, association: association) if generic_term)
          ].compact
        end

        def controller_action
          STANDARD_CONTROLLER_ACTIONS.find { name_parts.include?(it.to_s) }
        end

        def generic_term
          GENERIC_TERMS.find { name_parts.include?(it) }
        end
    end

    class ScopeBody
      include RuboCop::Callbacksystems::Helpers

      def initialize(body)
        @body = body
      end

      def eager_loading_association
        association_name_for(eager_load_call) if eager_load_call
      end

      private
        attr_reader :body

        def eager_load_call
          scope_body&.each_descendant(:send)&.find { EAGER_LOADING_METHODS.include?(it.method_name) }
        end

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
          eager_load_node.first_argument&.then { it.sym_type? ? it.value.to_s : it.source }
        end
    end
end
