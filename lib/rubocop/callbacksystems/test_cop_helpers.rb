# Shared helpers for test-related cops.
# Provides the `test_block?` node matcher and common constants.
#
# @example
#   class MyCop < RuboCop::Cop::Base
#     include RuboCop::Callbacksystems::TestCopHelpers
#
#     def on_block(node)
#       return unless test_block?(node)
#       # ...
#     end
#   end
#
module RuboCop::Callbacksystems::TestCopHelpers
  HTTP_METHODS = %i[get post put patch delete].freeze

  def self.included(base)
    base.def_node_matcher :test_block?, <<~PATTERN
      (block (send nil? :test (str $_)) ...)
    PATTERN
  end
end
