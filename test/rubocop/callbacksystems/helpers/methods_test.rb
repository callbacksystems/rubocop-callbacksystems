require "helpers_test_case"

class RuboCop::Callbacksystems::Helpers::MethodsTest < HelpersTestCase
  test "parameter_names returns names of positional and keyword arguments" do
    method = find_method("def foo(a, b = 1, c:, d: 2); end", :foo)

    assert_equal %w[a b c d], Helpers.parameter_names(method)
  end

  test "parameter_names ignores splat, double splat, and block arguments" do
    method = find_method("def foo(a, *rest, **opts, &block); end", :foo)

    assert_equal %w[a], Helpers.parameter_names(method)
  end
end
