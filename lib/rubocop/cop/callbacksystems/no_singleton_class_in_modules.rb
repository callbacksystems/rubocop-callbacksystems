# Forbids using `class << self` inside modules.
# Use `extend self` instead to define module-level methods.
#
# `class << self` in modules is an imperative way to define methods
# when a more declarative `extend self` approach exists.
#
# @example
#   # bad - using class << self in module
#   module Calculator
#     class << self
#       def add(a, b)
#         a + b
#       end
#     end
#   end
#
#   # good - using extend self
#   module Calculator
#     extend self
#
#     def add(a, b)
#       a + b
#     end
#   end
#
class RuboCop::Cop::Callbacksystems::NoSingletonClassInModules < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Use `extend self` instead of `class << self` in modules."

  def on_sclass(node)
    add_offense(node, message: MESSAGE) if singleton_class_in_module?(node)
  end

  private
    def singleton_class_in_module?(node)
      node.identifier.self_type? && enclosing_class_or_module_of(node)&.module_type?
    end
end
