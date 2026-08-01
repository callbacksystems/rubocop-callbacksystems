require "test_helper"

class RuboCop::Cop::Callbacksystems::PrivateDelegatePlacementTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PrivateDelegatePlacement

  test "registers offense for a private delegate above the private section" do
    offenses = assert_offense <<~RUBY
      class Report
        delegate :total, to: :order, private: true

        private
          attr_reader :order
      end
    RUBY

    assert_includes offenses.first.message, "private section"
  end

  test "registers offense when the class has no private section" do
    assert_offense <<~RUBY
      class Report
        delegate :total, to: :order, private: true

        def to_s
          total.to_s
        end
      end
    RUBY
  end

  test "allows a private delegate inside the private section" do
    assert_no_offense <<~RUBY
      class Report
        private
          attr_reader :order
          delegate :total, to: :order, private: true
      end
    RUBY
  end

  test "allows a public delegate above the private section" do
    assert_no_offense <<~RUBY
      class Report
        delegate :total, to: :order

        private
          attr_reader :order
      end
    RUBY
  end

  test "allows a private delegate inside a singleton section" do
    assert_no_offense <<~RUBY
      class Report
        class << self
          private
            delegate :total, to: :order, private: true
        end
      end
    RUBY
  end

  test "autocorrects by moving it below the private declarations" do
    assert_correction \
      <<~RUBY,
        class Report
          delegate :total, to: :order, private: true

          def to_s
            total.to_s
          end

          private
            attr_reader :order
        end
      RUBY
      <<~RUBY
        class Report
          def to_s
            total.to_s
          end

          private
            attr_reader :order
            delegate :total, to: :order, private: true
        end
      RUBY
  end

  test "autocorrects by moving it right after the private keyword" do
    assert_correction \
      <<~RUBY,
        class Report
          delegate :total, to: :order, private: true

          private
            def order
            end
        end
      RUBY
      <<~RUBY
        class Report
          private
            delegate :total, to: :order, private: true
            def order
            end
        end
      RUBY
  end

  test "autocorrects by opening a private section at the end of the body" do
    assert_correction \
      <<~RUBY,
        class Report
          delegate :total, to: :order, private: true

          def to_s
            total.to_s
          end
        end
      RUBY
      <<~RUBY
        class Report
          def to_s
            total.to_s
          end

          private
            delegate :total, to: :order, private: true
        end
      RUBY
  end

  test "autocorrects a delegate strayed below the methods of its section" do
    assert_correction \
      <<~RUBY,
        class Report
          private
            attr_reader :order

            def formatted_total
              total.to_s
            end

            delegate :total, to: :order, private: true
        end
      RUBY
      <<~RUBY
        class Report
          private
            attr_reader :order
            delegate :total, to: :order, private: true

            def formatted_total
              total.to_s
            end
        end
      RUBY
  end

  test "no offense for a delegate after the section constants" do
    assert_no_offense <<~RUBY
      class Report
        private
          FORMATS = %i[ plain html ].freeze

          delegate :total, to: :order, private: true

          def formatted_total
            total.to_s
          end
      end
    RUBY
  end

  test "no offense when moving up would cross a constant the delegate reads" do
    assert_no_offense <<~RUBY
      class Report
        private
          def formatted_total
            total.to_s
          end

          REGISTRY = Registry.new
          delegate :total, to: REGISTRY, private: true
      end
    RUBY
  end

  test "autocorrects a nested class by its own indentation" do
    assert_correction \
      <<~RUBY,
        module Billing
          class Report
              delegate :total, to: :order, private: true

              def to_s
                total.to_s
              end
          end
        end
      RUBY
      <<~RUBY
        module Billing
          class Report
              def to_s
                total.to_s
              end

              private
                  delegate :total, to: :order, private: true
          end
        end
      RUBY
  end
end
