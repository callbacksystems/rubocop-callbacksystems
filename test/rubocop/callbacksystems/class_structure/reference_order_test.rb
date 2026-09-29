require "test_helper"

class RuboCop::Callbacksystems::ClassStructure::ReferenceOrderTest < ActiveSupport::TestCase
  test "each walks a caller before the names it refers to" do
    order = RuboCop::Callbacksystems::ClassStructure::ReferenceOrder.new \
      %i[ process helper ], { process: %i[ helper ], helper: [] }

    assert_equal %i[ process helper ], order.to_a
  end

  test "each walks depth first, so a callee's own callees follow it" do
    graph = { process: %i[ first second ], first: %i[ deep ], second: [], deep: [] }
    order = RuboCop::Callbacksystems::ClassStructure::ReferenceOrder.new(%i[ process ], graph)

    assert_equal %i[ process first deep second ], order.to_a
  end

  test "each yields a name once, however many refer to it" do
    graph = { first: %i[ shared ], second: %i[ shared ], shared: [] }
    order = RuboCop::Callbacksystems::ClassStructure::ReferenceOrder.new(%i[ first second ], graph)

    assert_equal %i[ first shared second ], order.to_a
  end

  test "each skips a name the graph does not hold" do
    order = RuboCop::Callbacksystems::ClassStructure::ReferenceOrder.new \
      %i[ process unknown ], { process: %i[ missing ] }

    assert_equal %i[ process ], order.to_a
  end

  test "each survives a cycle between two names" do
    graph = { first: %i[ second ], second: %i[ first ] }
    order = RuboCop::Callbacksystems::ClassStructure::ReferenceOrder.new(%i[ first second ], graph)

    assert_equal %i[ first second ], order.to_a
  end

  test "each follows the order of the seeds it was given" do
    order = RuboCop::Callbacksystems::ClassStructure::ReferenceOrder.new(%i[ second first ], { first: [], second: [] })

    assert_equal %i[ second first ], order.to_a
  end

  test "each walks a graph deeper than the Ruby stack" do
    names = 5_000.times.map { :"name_#{it}" }
    graph = names.each_with_index.to_h { |name, index| [ name, Array(names[index + 1]) ] }
    order = RuboCop::Callbacksystems::ClassStructure::ReferenceOrder.new([ names.first ], graph)

    assert_equal names, order.to_a
  end

  test "each yields nothing for no seeds" do
    assert_empty RuboCop::Callbacksystems::ClassStructure::ReferenceOrder.new([], {}).to_a
  end
end
