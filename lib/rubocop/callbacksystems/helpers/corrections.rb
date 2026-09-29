module RuboCop::Callbacksystems::Helpers::Corrections
  # A shorthand keyword's synthetic value shares the key's source range, so replacing that node would rename the key.
  def replace_expression(corrector, node, with:)
    if shorthand_keyword_value?(node)
      corrector.insert_after(node.parent, " #{with}")
    else
      corrector.replace(node, with)
    end
  end

  private
    def shorthand_keyword_value?(node)
      node.parent&.pair_type? && node.equal?(node.parent.value) && node.parent.value_omission?
    end
end
