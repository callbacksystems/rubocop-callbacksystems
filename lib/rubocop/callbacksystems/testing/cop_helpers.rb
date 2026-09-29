module RuboCop::Callbacksystems::Testing::CopHelpers
  extend RuboCop::AST::NodePattern::Macros

  # @!method test_block?(node)
  def_node_matcher :test_block?, <<~PATTERN
    (any_block (send {nil? (self)} :test (str $_)) ...)
  PATTERN

  # @!method setup_block?(node)
  def_node_matcher :setup_block?, <<~PATTERN
    (any_block (send {nil? (self)} :setup) ...)
  PATTERN

  private
    HTTP_METHODS = %i[ get post put patch delete ]
    RESPONSE_ASSERTIONS = %i[ assert_response assert_redirected_to ]

    def test_blocks(scope = processed_source.ast)
      nodes_in(scope, :any_block).select { test_block?(it) }
    end

    def setup_blocks(scope = processed_source.ast)
      nodes_in(scope, :any_block).select { setup_block?(it) }
    end

    def immediate_calls_in(statement)
      immediate_calls_by_statement[statement] ||= RuboCop::Callbacksystems::Execution::Immediate.new(statement)
        .nodes_of_type(:send, :csend)
    end

    def immediate_calls_by_statement
      @immediate_calls_by_statement ||= {}.compare_by_identity
    end

    def response_assertion?(send_node)
      call_on_self?(send_node) && RESPONSE_ASSERTIONS.include?(send_node.method_name)
    end

    def http_request?(send_node)
      call_on_self?(send_node) && HTTP_METHODS.include?(send_node.method_name)
    end
end
