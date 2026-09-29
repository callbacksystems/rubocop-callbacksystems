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

  test "ignores a private delegate outside a class or module body" do
    assert_no_offense "delegate :total, to: :order, private: true\n"
  end

  test "autocorrects a delegate that is the only statement in the body" do
    original = <<~RUBY
      class Report
        delegate :total, to: :order, private: true
      end
    RUBY
    corrected = <<~RUBY
      class Report
        private
          delegate :total, to: :order, private: true
      end
    RUBY

    assert_correction original, corrected
    assert_no_correction corrected
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

  test "relocates the delegate together with the comment above it" do
    assert_correction \
      <<~RUBY,
        class Report
          # Read by the summary.
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
            # Read by the summary.
            delegate :total, to: :order, private: true
        end
      RUBY
  end

  test "reports without moving a delegate whose tooling directive would change scope" do
    assert_uncorrectable_offense <<~RUBY
      class Report
        # :nocov:
        delegate :total, to: :order, private: true

        def to_s
          total.to_s
        end

        private
          attr_reader :order
        # :nocov:
      end
    RUBY
  end

  test "relocates the delegate together with the comment closing its line" do
    assert_correction \
      <<~RUBY,
        class Report
          delegate :total, to: :order, private: true # read by the summary

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
            delegate :total, to: :order, private: true # read by the summary
        end
      RUBY
  end

  test "leaves the comment closing the anchor on its own declaration" do
    assert_correction \
      <<~RUBY,
        class Report
          delegate :total, to: :order, private: true # read by the summary

          def to_s
            total.to_s
          end

          private
            attr_reader :order # the source of the total
        end
      RUBY
      <<~RUBY
        class Report
          def to_s
            total.to_s
          end

          private
            attr_reader :order # the source of the total
            delegate :total, to: :order, private: true # read by the summary
        end
      RUBY
  end

  test "reports without moving a delegate across an independent comment" do
    assert_uncorrectable_offense <<~RUBY
      class Report
        delegate :total, to: :order, private: true

        # Public behavior.

        def to_s
          total.to_s
        end

        private
          attr_reader :order
      end
    RUBY
  end

  test "reports without moving a delegate across an executable call" do
    assert_uncorrectable_offense <<~RUBY
      class Report
        delegate :total, to: :order, private: true
        register_observer :total

        private
          attr_reader :order
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
          FORMATS = %i[ plain html ]

          delegate :total, to: :order, private: true

          def formatted_total
            total.to_s
          end
      end
    RUBY
  end

  test "reports without correcting when moving up would cross a constant the delegate reads" do
    assert_uncorrectable_offense <<~RUBY
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

  test "reports without correcting when moving down would replace an explicit method" do
    assert_uncorrectable_offense <<~RUBY
      class Report
        delegate :total, to: :order, private: true

        def total
          10
        end

        private
          attr_reader :order
      end
    RUBY
  end

  test "reports without replacing an explicit method through a prefixed delegate" do
    assert_uncorrectable_offense <<~RUBY
      class Report
        delegate :name, to: :user, prefix: true, private: true

        def user_name
          "report"
        end

        private
          attr_reader :user
      end
    RUBY
  end

  test "reports without moving a delegate whose prefix is dynamic" do
    assert_uncorrectable_offense <<~RUBY
      class Report
        delegate :name, to: :user, prefix: method_prefix, private: true

        private
          attr_reader :user
      end
    RUBY
  end

  test "reports without correcting when moving up would replace an explicit method" do
    assert_uncorrectable_offense <<~RUBY
      class Report
        private
          attr_reader :order

          def total
            10
          end

          delegate :total, to: :order, private: true
      end
    RUBY
  end

  test "reports without correcting when moving would reverse another declaration of the method" do
    assert_uncorrectable_offense <<~RUBY
      class Report
        delegate :total, to: :order, private: true

        private
          attr_reader :total
          attr_reader :order
      end
    RUBY
  end

  test "reads the writer made by attr_writer when preserving declaration precedence" do
    assert_uncorrectable_offense <<~RUBY
      class Report
        delegate :total=, to: :order, private: true

        private
          attr_writer :total
          attr_reader :order
      end
    RUBY
  end

  test "reads both methods made by attr_accessor when preserving declaration precedence" do
    assert_uncorrectable_offense <<~RUBY
      class Report
        delegate :total, to: :order, private: true

        private
          attr_accessor :total
          attr_reader :order
      end
    RUBY
  end

  test "does not reverse two delegates defining the same method" do
    assert_uncorrectable_offense <<~RUBY
      class Report
        delegate :total, to: :order, private: true

        private
          delegate :total, to: :fallback, private: true
      end
    RUBY
  end

  test "does not move a private delegate across a dynamic delegate" do
    assert_uncorrectable_offense <<~RUBY
      class Report
        delegate :total, to: :order, private: true

        private
          delegate *METHODS, to: :fallback
          attr_reader :order
      end
    RUBY
  end

  test "does not move a private delegate across a dynamically named accessor" do
    assert_uncorrectable_offense <<~RUBY
      class Report
        delegate :total, to: :order, private: true

        private
          attr_reader method_name
          attr_reader :order
      end
    RUBY
  end

  test "preserves relative indentation and comments in a multiline delegate" do
    original = <<~RUBY
      class Report
        # Read by the summary.
        delegate(
          :total,

          to: :order,
          private: true
        ) # Defines a private reader.

        private
          attr_reader :order
      end
    RUBY
    corrected = <<~RUBY
      class Report
        private
          attr_reader :order
          # Read by the summary.
          delegate(
            :total,

            to: :order,
            private: true
          ) # Defines a private reader.
      end
    RUBY

    assert_correction original, corrected
    assert_no_correction corrected
  end

  test "preserves the value of a squiggly heredoc while moving a delegate" do
    original = <<~RUBY
      class Report
        delegate :total, to: <<~TARGET, private: true
          order
        TARGET

        private
          attr_reader :order
      end
    RUBY
    corrected = <<~RUBY
      class Report
        private
          attr_reader :order
          delegate :total, to: <<~TARGET, private: true
            order
          TARGET
      end
    RUBY

    assert_correction original, corrected
    assert_no_correction corrected
  end

  test "reports without changing the value of an indented heredoc" do
    assert_uncorrectable_offense <<~RUBY
      class Report
        delegate :total, to: <<-TARGET, private: true
          order
        TARGET

        private
          attr_reader :order
      end
    RUBY
  end

  test "reports without rewriting a delegate sharing the class declaration line" do
    assert_uncorrectable_offense <<~RUBY
      class Report; delegate :total, to: :order, private: true; end
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
