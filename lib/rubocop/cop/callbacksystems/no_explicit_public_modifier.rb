# Do not use explicit `public` modifier. Public methods should be at the beginning
# of the class/module, before any `private` or `protected` sections.
#
# @example
#   # bad - using explicit public modifier
#   class Foo
#     private
#       def private_method; end
#
#     public
#       def public_method; end
#   end
#
#   # bad - using public with method name
#   class Foo
#     def some_method; end
#     public :some_method
#   end
#
#   # good - public methods at the beginning
#   class Foo
#     def public_method; end
#
#     private
#       def private_method; end
#   end
#
class RuboCop::Cop::Callbacksystems::NoExplicitPublicModifier < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Do not use `public` modifier. Public methods should be defined at the beginning of the class."

  def on_send(node)
    add_offense(node, message: MESSAGE) if public_modifier?(node)
  end

  alias on_csend on_send

  private
    def public_modifier?(node)
      node.receiver.nil? && node.method?(:public) && !inside_nested_class?(node)
    end

    def inside_nested_class?(node)
      node.each_ancestor(:class, :module).drop(1).any?
    end
end
