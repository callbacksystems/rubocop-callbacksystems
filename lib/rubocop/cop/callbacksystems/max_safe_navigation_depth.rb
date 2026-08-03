# Deeply chained safe navigation (`a&.b&.c&.d&.e`) signals deep coupling or
# poor data modelling. Refactor: pre-validate, restructure the object, or
# extract an intermediate.
#
# @example MaxDepth: 3 (default)
#   # bad - four safe-navigation links
#   value = account&.owner&.address&.city
#
#   # good - extract an intermediate
#   owner = account&.owner
#   value = owner&.address&.city
#
class RuboCop::Cop::Callbacksystems::MaxSafeNavigationDepth < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Safe-navigation depth %<depth>d exceeds maximum %<maximum>d. Restructure or extract intermediates."

  def on_csend(node)
    if outermost_safe_navigation?(node)
      depth = safe_navigation_count_in(chain_top_of(node))
      add_offense(node, message: format(MESSAGE, depth: depth, maximum: max_depth)) if depth > max_depth
    end
  end

  private
    # The chain's outermost `&.`, so the chain is counted once.
    def outermost_safe_navigation?(node)
      child = node
      ancestor = node.parent
      while navigation_link?(ancestor, child)
        return false if ancestor.csend_type?

        child = ancestor
        ancestor = ancestor.parent
      end
      true
    end

    def navigation_link?(parent, child)
      parent&.call_type? && parent.receiver.equal?(child)
    end

    # Every link in the chain, not just a consecutive run: `a&.b.c&.d` is depth 2.
    def safe_navigation_count_in(node)
      if node&.call_type?
        (node.csend_type? ? 1 : 0) + safe_navigation_count_in(node.receiver)
      else
        0
      end
    end

    def chain_top_of(node)
      navigation_link?(node.parent, node) ? chain_top_of(node.parent) : node
    end

    def max_depth
      cop_config["MaxDepth"]
    end
end
