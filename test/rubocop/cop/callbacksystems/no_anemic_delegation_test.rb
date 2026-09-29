require "test_helper"

class NoAnemicDelegationTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoAnemicDelegation

  test "registers offense for private method that only delegates to new instance" do
    offenses = assert_offense <<~RUBY, count: 1
      class Foo
        private
          def eager_loading_association(body)
            ScopeBody.new(body).eager_loading_association
          end
      end
    RUBY

    assert_includes offenses.first.message, "eager_loading_association"
  end

  test "registers offense for private collect pattern" do
    assert_offense <<~RUBY, count: 1
      class Foo
        private
          def macro_references(body)
            MacroReferences.new(body).collect
          end
      end
    RUBY
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
    assert_offense <<~RUBY, count: 1
      class Foo
        private
          def analyze(node, config)
            Analyzer.new(node, config).analyze
          end
      end
    RUBY
  end

  test "allows delegation whose argument list destructures one parameter" do
    assert_no_offense <<~RUBY
      class Foo
        private
          def analyze((node, config))
            Analyzer.new(node, config).analyze
          end
      end
    RUBY
  end

  test "registers offense when constructor and delegated call only receive parameters" do
    assert_offense <<~RUBY
      class Foo
        private
          def analyze(node, config)
            Analyzer.new(node).analyze(config)
          end
      end
    RUBY
  end

  test "allows a delegated call given something other than a parameter" do
    assert_no_offense <<~RUBY
      class Foo
        private
          def analyze(node)
            Analyzer.new(node).analyze(extra_config)
          end
      end
    RUBY
  end

  test "allows a constructor or delegated call given a transformed parameter" do
    assert_no_offense <<~RUBY
      class Foo
        private
          def analyze(node)
            Analyzer.new(node.body).analyze(node)
          end
      end

      class Bar
        private
          def analyze(node)
            Analyzer.new(node).analyze(node.body)
          end
      end
    RUBY
  end

  test "allows protected delegation because it remains part of the callable interface" do
    assert_no_offense <<~RUBY
      class Foo
        protected
          def analyze(node)
            Analyzer.new(node).analyze
          end
      end
    RUBY
  end

  test "allows a singleton method left public by an instance private section" do
    assert_no_offense <<~RUBY
      class Foo
        private
          def self.analyze(node)
            Analyzer.new(node).analyze
          end
      end
    RUBY
  end

  test "registers offense for a singleton method made genuinely private" do
    assert_offense <<~RUBY, count: 2
      class Foo
        private_class_method def self.analyze(node)
          Analyzer.new(node).analyze
        end

        class << self
          private
            def collect(node)
              Collector.new(node).collect
            end
        end
      end
    RUBY
  end

  test "ignores method declarations nested in another method or a lambda" do
    assert_no_offense <<~RUBY
      class Foo
        private
          def install
            def analyze(node)
              Analyzer.new(node).analyze
            end
          end

          INSTALLER = -> do
            def collect(node)
              Collector.new(node).collect
            end
          end
      end
    RUBY
  end

  test "keeps a private method in a nested class within that class's own scope" do
    assert_offense <<~RUBY, count: 1
      class Foo
        private
          class Analyzer
            private
              def analyze(node)
                Result.new(node).analyze
              end
          end
      end
    RUBY
  end

  test "allows a method forwarding to a bare call" do
    assert_no_offense <<~RUBY
      class Report
        private
          def title
            heading
          end
      end
    RUBY
  end

  test "allows a method forwarding to an instance built without a constant" do
    assert_no_offense <<~RUBY
      class Report
        private
          def title(text)
            new(text).title
          end
      end
    RUBY
  end
end
