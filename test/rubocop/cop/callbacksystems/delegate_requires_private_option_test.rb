require "test_helper"

class RuboCop::Cop::Callbacksystems::DelegateRequiresPrivateOptionTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::DelegateRequiresPrivateOption

  test "flags delegate without private: true under private keyword" do
    assert_offense <<~RUBY
      class Foo
        def initialize(node)
          @node = node
        end

        private
          attr_reader :node
          delegate :body, to: :node
      end
    RUBY
  end

  test "flags delegate with other options but no private: true under private keyword" do
    assert_offense <<~RUBY
      class Foo
        private
          delegate :name, :email, to: :user, allow_nil: true
      end
    RUBY
  end

  test "does not flag delegate with private: true" do
    assert_no_offense <<~RUBY
      class Foo
        private
          delegate :body, to: :node, private: true
      end
    RUBY
  end

  test "does not flag delegate at the public section" do
    assert_no_offense <<~RUBY
      class Foo
        delegate :body, to: :node
      end
    RUBY
  end

  test "does not flag delegate at module level (no enclosing class)" do
    assert_no_offense <<~RUBY
      delegate :body, to: :node
    RUBY
  end

  test "does not flag unrelated send calls under private" do
    assert_no_offense <<~RUBY
      class Foo
        private
          attr_reader :node
      end
    RUBY
  end

  test "autocorrects by appending private: true" do
    assert_correction <<~SOURCE, <<~CORRECTED
      class Foo
        private
          delegate :body, to: :node
      end
    SOURCE
      class Foo
        private
          delegate :body, to: :node, private: true
      end
    CORRECTED
  end

  test "autocorrects preserving other options" do
    assert_correction <<~SOURCE, <<~CORRECTED
      class Foo
        private
          delegate :name, :email, to: :user, allow_nil: true
      end
    SOURCE
      class Foo
        private
          delegate :name, :email, to: :user, allow_nil: true, private: true
      end
    CORRECTED
  end

  test "does not flag delegate in protected section" do
    assert_no_offense <<~RUBY
      class Foo
        protected
          delegate :body, to: :node
      end
    RUBY
  end
end
