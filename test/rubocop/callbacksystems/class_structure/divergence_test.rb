require "test_helper"

class RuboCop::Callbacksystems::ClassStructure::DivergenceTest < ActiveSupport::TestCase
  test "found? is true when the names depart from the order" do
    assert_predicate divergence(%i[ a c b ], from: %i[ a b c ]), :found?
  end

  test "found? is false when the names follow the order" do
    assert_not_predicate divergence(%i[ a b c ], from: %i[ a b c ]), :found?
    assert_not_predicate divergence([], from: %i[ a ]), :found?
  end

  test "found? is false when the sequences do not hold the same names" do
    assert_not_predicate divergence(%i[ a a b ], from: %i[ a b ]), :found?
    assert_not_predicate divergence(%i[ a b ], from: %i[ a c ]), :found?
  end

  test "index is the first position holding a different name" do
    assert_equal 1, divergence(%i[ a c b ], from: %i[ a b c ]).index
  end

  test "index is nil when the names follow the order" do
    assert_nil divergence(%i[ a b ], from: %i[ a b c ]).index
  end

  test "expected is the name the order holds at the divergence" do
    assert_equal :b, divergence(%i[ a c b ], from: %i[ a b c ]).expected
  end

  test "actual is the name found at the divergence" do
    assert_equal :c, divergence(%i[ a c b ], from: %i[ a b c ]).actual
  end

  private
    def divergence(names, from:)
      RuboCop::Callbacksystems::ClassStructure::Divergence.new(names, from:)
    end
end
