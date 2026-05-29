require "test_helper"

class NoAnemicDelegationTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoAnemicDelegation

  test "registers offense for private method that only delegates to new instance" do
    offenses = assert_offense <<~RUBY
      class Foo
        private
          def eager_loading_association(body)
            ScopeBody.new(body).eager_loading_association
          end
      end
    RUBY

    assert_equal 1, offenses.count
    assert_includes offenses.first.message, "eager_loading_association"
  end

  test "registers offense for private collect pattern" do
    offenses = assert_offense <<~RUBY
      class Foo
        private
          def macro_references(body)
            MacroReferences.new(body).collect
          end
      end
    RUBY

    assert_equal 1, offenses.count
  end

  test "allows public method that delegates" do
    assert_no_offense <<~RUBY
      class Foo
        def eager_loading_association(body)
          ScopeBody.new(body).eager_loading_association
        end
      end
    RUBY
  end

  test "allows predicate method that delegates" do
    assert_no_offense <<~RUBY
      class Foo
        private
          def valid?(body)
            Validator.new(body).valid?
          end
      end
    RUBY
  end

  test "no offense when method does more than delegate" do
    assert_no_offense <<~RUBY
      class Foo
        private
          def eager_loading_association(body)
            result = ScopeBody.new(body).eager_loading_association
            result.presence || default_association
          end
      end
    RUBY
  end

  test "no offense when arguments differ" do
    assert_no_offense <<~RUBY
      class Foo
        private
          def process(body)
            Processor.new(body, extra_config).process
          end
      end
    RUBY
  end

  test "no offense for regular method calls" do
    assert_no_offense <<~RUBY
      def process(body)
        body.process
      end
    RUBY
  end

  test "no offense when receiver is not a new instance" do
    assert_no_offense <<~RUBY
      def process(processor)
        processor.process
      end
    RUBY
  end

  test "registers offense for private method with multiple parameters" do
    offenses = assert_offense <<~RUBY
      class Foo
        private
          def analyze(node, config)
            Analyzer.new(node, config).analyze
          end
      end
    RUBY

    assert_equal 1, offenses.count
  end
end
