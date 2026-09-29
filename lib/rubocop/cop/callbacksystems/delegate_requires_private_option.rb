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

  def on_send(node)
    report DelegateCall.new(node)
  end

  alias on_csend on_send

  private
    class DelegateCall
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "`delegate` under a `private` section must pass `private: true`; visibility is not inherited " \
        "automatically."

      def initialize(node)
        @node = node
      end

      def offense
        if missing_private_option?
          RuboCop::Callbacksystems::Offense.new(node, MESSAGE, correcting: macro.private_option_known?) { correct(it) }
        end
      end

      private
        attr_reader :node

        def missing_private_option?
          macro.macro? && !macro.private? && inside_private_section?
        end

        def macro
          @macro ||= RuboCop::Callbacksystems::Methods::DelegateMacro.new(node)
        end

        def inside_private_section?
          enclosing_body && visibility_at(node, enclosing_body) == :private
        end

        def enclosing_body
          @enclosing_body ||= enclosing_body_for(node)
        end

        def correct(corrector)
          if macro.private_option
            replace_expression(corrector, macro.private_option.value, with: "true")
          else
            corrector.insert_after(macro.last_option, ", private: true")
          end
        end
    end
end
