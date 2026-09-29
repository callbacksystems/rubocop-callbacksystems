# Deeply chained safe navigation (`a&.b&.c&.d&.e`) signals deep coupling or
# poor data modeling. Refactor: pre-validate, restructure the object, or
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
  def on_new_investigation
    @navigation_context = NavigationContext.new
  end

  def on_csend(node)
    report NavigationChain.new(node, navigation_context, max_depth: cop_config["MaxDepth"])
  end

  private
    attr_reader :navigation_context

    # The chain a safe-navigation call sits in, measured once from its outermost link so every chain is reported once.
    class NavigationChain
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Safe-navigation depth %<depth>d exceeds maximum %<maximum>d. Restructure or extract intermediates."

      def initialize(node, navigation_context, max_depth:)
        @node = node
        @navigation_context = navigation_context
        @max_depth = max_depth
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(node, message) if outermost?(node) && depth > max_depth
      end

      private
        attr_reader :node, :navigation_context, :max_depth
        delegate :outermost?, :top_of, to: :navigation_context, private: true

        # Every link in the chain counts, not just a consecutive run (`a&.b.c&.d` is depth 2), matching the JS rule.
        def depth
          @depth ||= links_down_from(top_of(node)).count(&:csend_type?)
        end

        def links_down_from(link)
          if block_given?
            while link&.call_type?
              yield link
              link = link.receiver
            end
          else
            to_enum(__method__, link)
          end
        end

        def message
          format(MESSAGE, depth:, maximum: max_depth)
        end
    end

    # Receiver-chain ancestry shared by every safe link in one investigation, with iterative path compression.
    class NavigationContext
      Facts = Data.define(:top, :safe_link)
      NO_FACTS = Facts.new(nil, nil)

      def initialize
        @facts_by_link = {}.compare_by_identity
      end

      def outermost?(node)
        safe_link_at_or_above(chained_parent_of(node)).nil?
      end

      def top_of(node)
        facts_for(node).top
      end

      private
        attr_reader :facts_by_link

        def safe_link_at_or_above(node)
          node&.then { facts_for(it).safe_link }
        end

        def facts_for(node)
          path = uncached_path_from(node)
          facts = inherited_facts_of(path)
          path.reverse_each do |link|
            facts = Facts.new(facts.top || link, link.csend_type? ? link : facts.safe_link)
            facts_by_link[link] = facts
          end
          facts_by_link.fetch(node)
        end

        def uncached_path_from(node)
          [].then do |path|
            while node && !facts_by_link.key?(node)
              path << node
              node = chained_parent_of(node)
            end
            path
          end
        end

        def chained_parent_of(link)
          link.parent&.then { it if it.call_type? && it.receiver.equal?(link) }
        end

        def inherited_facts_of(path)
          path.last&.then { facts_by_link.fetch(chained_parent_of(it), NO_FACTS) } || NO_FACTS
        end
    end
end
