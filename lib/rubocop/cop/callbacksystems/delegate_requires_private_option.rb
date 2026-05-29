# `delegate` does not inherit the visibility of the surrounding section.
# A `delegate` placed under a `private` keyword still defines public methods
# unless `private: true` is passed explicitly.
#
# @example
#   # bad - `body` ends up public despite the surrounding `private`
#   class Foo
#     def initialize(node)
#       @node = node
#     end
#
#     private
#       attr_reader :node
#       delegate :body, to: :node
#   end
#
#   # good - opts into private visibility explicitly
#   class Foo
#     def initialize(node)
#       @node = node
#     end
#
#     private
#       attr_reader :node
#       delegate :body, to: :node, private: true
#   end
#
class RuboCop::Cop::Callbacksystems::DelegateRequiresPrivateOption < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = "`delegate` under a `private` section must pass `private: true`; visibility is not inherited automatically."

  def on_send(node)
    call = DelegateCall.new(node)
    add_offense(node, message: MESSAGE) { call.add_private_option(it) } if call.offense?
  end

  alias on_csend on_send

  private
    class DelegateCall
      include RuboCop::Callbacksystems::Helpers

      def initialize(node)
        @node = node
      end

      def offense?
        delegate_call? && inside_private_section? && !private_option_set?
      end

      def add_private_option(corrector)
        corrector.insert_after(options_hash.pairs.last, ", private: true")
      end

      private
        attr_reader :node

        def delegate_call?
          bare_send?(node) && node.method?(:delegate) && options_hash
        end

        def options_hash
          node.last_argument if node.last_argument&.hash_type?
        end

        def inside_private_section?
          body = enclosing_body_for(node)
          body && visibility_at(node, body) == :private
        end

        def private_option_set?
          options_hash.pairs.any? do |pair|
            pair.key.sym_type? && pair.key.value == :private && pair.value.true_type?
          end
        end
    end
end
