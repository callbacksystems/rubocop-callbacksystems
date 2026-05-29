require "test_helper"

class RuboCop::Cop::Callbacksystems::PreferPositiveWrapTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PreferPositiveWrap

  test "registers offense for a bare-return guard with a short happy path" do
    assert_offense <<~RUBY
      def label
        return unless ready?
        compute_label
      end
    RUBY
  end

  test "registers offense for a value-return guard with a short happy path" do
    assert_offense <<~RUBY
      def descriptor
        return nil unless ready?
        { kind: :default }
      end
    RUBY
  end

  test "allows a deeply nested happy path: wrap would breach Metrics/BlockNesting" do
    assert_no_offense <<~RUBY
      def process
        return unless ready?
        if a
          if b
            if c
              do_stuff
            end
          end
        end
      end
    RUBY
  end

  test "allows a positive guard: `return if cond` is not a negative form" do
    assert_no_offense <<~RUBY
      def label
        return if hidden?
        compute_label
      end
    RUBY
  end

  test "allows a single-statement body" do
    assert_no_offense <<~RUBY
      def label
        compute_label
      end
    RUBY
  end

  test "rewrites the bare guard to a positive if-block" do
    assert_correction <<~RUBY, <<~CORRECTED
      def label
        return unless ready?
        compute_label
      end
    RUBY
      def label
        if ready?
          compute_label
        end
      end
    CORRECTED
  end

  test "rewrites the value guard keeping the value in an else branch" do
    assert_correction <<~RUBY, <<~CORRECTED
      def descriptor
        return nil unless ready?
        { kind: :default }
      end
    RUBY
      def descriptor
        if ready?
          { kind: :default }
        else
          nil
        end
      end
    CORRECTED
  end

  test "rewrites a multi-statement happy path" do
    assert_correction <<~RUBY, <<~CORRECTED
      def process
        return unless ready?
        first_step
        second_step
        third_step
      end
    RUBY
      def process
        if ready?
          first_step
          second_step
          third_step
        end
      end
    CORRECTED
  end
end
