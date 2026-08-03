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

  test "leaves a public that reopens visibility after private for a human" do
    assert_correction <<~RUBY, <<~SAME, file: "app/models/foo.rb"
      class Foo
        private
          def private_method; end

        public
          def public_method; end
      end
    RUBY
      class Foo
        private
          def private_method; end

        public
          def public_method; end
      end
    SAME
  end

  test "removes a redundant public with no preceding private" do
    assert_correction <<~RUBY, <<~CORRECTED, file: "app/models/foo.rb"
      class Foo
        public
        def public_method; end
      end
    RUBY
      class Foo
        def public_method; end
      end
    CORRECTED
  end

  test "removes a redundant public with a method name" do
    assert_correction <<~RUBY, <<~CORRECTED, file: "app/models/foo.rb"
      class Foo
        def some_method; end
        public :some_method
      end
    RUBY
      class Foo
        def some_method; end
      end
    CORRECTED
  end

  test "keeps the declaration when public modifies one" do
    assert_correction \
      <<~RUBY, <<~CORRECTED
        class Order
          public attr_reader :token
        end
      RUBY
        class Order
          attr_reader :token
        end
      CORRECTED
  end

  test "keeps a delegate the public modifier stands in front of" do
    assert_correction \
      <<~RUBY, <<~CORRECTED
        class Order
          public delegate :name, to: :user
        end
      RUBY
        class Order
          delegate :name, to: :user
        end
      CORRECTED
  end
end
