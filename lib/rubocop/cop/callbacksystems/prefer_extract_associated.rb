# Prefers `extract_associated` when a model query preloads one association and
# then collects that same association. Active Record supplies this exact
# operation as one method, keeping the association's name in one place.
#
# The receiver is assumed to be an Active Record relation. Comments prevent
# autocorrection, and a guarded preload followed by an unguarded map is left
# alone because collapsing it would change what happens when the receiver is nil.
#
# @example
#   # bad
#   posts.preload(:author).map(&:author)
#   memberships.preload(:user).collect(&:user)
#
#   # good
#   posts.extract_associated(:author)
#   memberships.extract_associated(:user)
#
class RuboCop::Cop::Callbacksystems::PreferExtractAssociated < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = "Use `extract_associated(%<association>s)` instead of preloading and mapping the same association."

  # @!method association_extraction(node)
  def_node_matcher :association_extraction, <<~PATTERN
    (call $(call _ :preload $(sym _association)) {:map :collect} (block_pass (sym _association)))
  PATTERN

  def on_send(node)
    association_extraction(node) do |preload, association|
      next if preload.csend_type? && node.send_type?

      add_extraction_offense(node, preload:, association:)
    end
  end

  alias on_csend on_send

  private
    def add_extraction_offense(node, preload:, association:)
      message = format(MESSAGE, association: association.source)

      if source_comments.any_within?(node)
        add_offense(node, message:)
      else
        add_offense(node, message:) do |corrector|
          corrector.replace(node, replacement_for(preload, association:))
        end
      end
    end

    def replacement_for(preload, association:)
      "#{call_prefix_of(preload)}extract_associated(#{association.source})"
    end
end
