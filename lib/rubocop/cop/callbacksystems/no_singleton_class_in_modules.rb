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
    add_offense(node, message: MESSAGE) if singleton_section?(node) && lexical_owner_of(node)&.module_type?
  end

  private
    def lexical_owner_of(node)
      node.each_ancestor.find { lexical_boundary?(it) }
    end

    # A block may be evaluated with another receiver (`included`, `class_eval`, and friends), so its `self` cannot be
    # attributed to the module around the block from syntax alone.
    def lexical_boundary?(node)
      node.type?(:class, :module, :sclass, :def, :defs) || any_block_type?(node)
    end
end
