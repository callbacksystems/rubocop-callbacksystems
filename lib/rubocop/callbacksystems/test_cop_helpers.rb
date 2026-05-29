module RuboCop::Callbacksystems::TestCopHelpers
  extend ActiveSupport::Concern

  HTTP_METHODS = %i[get post put patch delete].freeze
  RESPONSE_ASSERTIONS = %i[assert_response assert_redirected_to].freeze

  included do
    # @!method test_block?(node)
    def_node_matcher :test_block?, <<~PATTERN
      (block (send nil? :test (str $_)) ...)
    PATTERN

    # @!method setup_block?(node)
    def_node_matcher :setup_block?, <<~PATTERN
      (block (send nil? :setup) ...)
    PATTERN
  end

  private
    def test_blocks(scope = processed_source.ast)
      scope ? scope.each_node(:block).select { test_block?(it) } : []
    end

    def setup_blocks(scope = processed_source.ast)
      scope ? scope.each_node(:block).select { setup_block?(it) } : []
    end

    def response_assertion?(send_node)
      send_node.receiver.nil? && RESPONSE_ASSERTIONS.include?(send_node.method_name)
    end

    def body_has_http_request?(node)
      node.body&.each_node(:send)&.any? { http_request?(it) }
    end

    def http_request?(send_node)
      send_node.receiver.nil? && HTTP_METHODS.include?(send_node.method_name)
    end
end
