require "test_helper"

class NoExplicitPublicModifierTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoExplicitPublicModifier

  test "reads a public modifier that stands alone in the file" do
    assert_offense <<~RUBY
      public
    RUBY
  end

  test "registers offense for standalone public modifier" do
    offenses = assert_offense <<~RUBY, count: 1, file: "app/models/foo.rb"
      class Foo
        private
          def private_method; end

        public
          def public_method; end
      end
    RUBY

    assert_includes offenses.first.message, "Do not use `public` modifier"
  end

  test "registers offense for public with method name" do
    assert_offense <<~RUBY, count: 1, file: "app/models/foo.rb"
      class Foo
        def some_method; end
        public :some_method
      end
    RUBY
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
    assert_offense <<~RUBY, count: 1, file: "app/models/foo.rb"
      module Foo
        private
          def private_method; end

        public
          def public_method; end
      end
    RUBY
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

  test "leaves a commented redundant public for a human rather than orphaning its explanation" do
    assert_uncorrectable_offense <<~RUBY, file: "app/models/foo.rb"
      class Foo
        public # Documents an intentionally exposed API boundary.
        def public_method; end
      end
    RUBY
  end

  test "removes a same-line public modifier without deleting the method beside it" do
    assert_correction <<~RUBY, <<~CORRECTED, file: "app/models/foo.rb"
      class Foo
        public; def public_method = true
      end
    RUBY
      class Foo
        def public_method = true
      end
    CORRECTED
  end

  test "leaves a public with a method name for a human even without a preceding private" do
    assert_no_correction <<~RUBY, file: "app/models/foo.rb"
      class Foo
        def some_method; end
        public :some_method
      end
    RUBY
  end

  test "leaves public with an inherited method name because removing it changes visibility" do
    assert_no_correction <<~RUBY, file: "app/models/foo.rb"
      class Foo < Parent
        public :inherited_private_method
      end
    RUBY
  end

  test "leaves a top-level public modifier for a human" do
    assert_no_correction <<~RUBY
      public
    RUBY
  end
end
