require "test_helper"

class NoExplicitPublicModifierTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoExplicitPublicModifier

  test "registers offense for standalone public modifier" do
    offenses = assert_offense <<~RUBY, file: "app/models/foo.rb"
      class Foo
        private
          def private_method; end

        public
          def public_method; end
      end
    RUBY

    assert_equal 1, offenses.count
    assert_includes offenses.first.message, "Do not use `public` modifier"
  end

  test "registers offense for public with method name" do
    offenses = assert_offense <<~RUBY, file: "app/models/foo.rb"
      class Foo
        def some_method; end
        public :some_method
      end
    RUBY

    assert_equal 1, offenses.count
  end

  test "no offense when no public modifier is used" do
    assert_no_offense <<~RUBY, file: "app/models/foo.rb"
      class Foo
        def public_method; end

        private
          def private_method; end
      end
    RUBY
  end

  test "no offense for public inside nested class" do
    assert_no_offense <<~RUBY, file: "app/models/foo.rb"
      class Foo
        private
          class Bar
            private
              def internal; end

            public
              def external; end
          end
      end
    RUBY
  end

  test "registers offense in module" do
    offenses = assert_offense <<~RUBY, file: "app/models/foo.rb"
      module Foo
        private
          def private_method; end

        public
          def public_method; end
      end
    RUBY

    assert_equal 1, offenses.count
  end
end
