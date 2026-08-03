require "test_helper"

class CollapseMultilineExpressionTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::CollapseMultilineExpression

  test "registers offense and corrects multiline hash that fits on one line" do
    assert_correction \
      <<~RUBY,
        x = {
          foo: 1,
          bar: 2
        }
      RUBY
      <<~RUBY
        x = { foo: 1, bar: 2 }
      RUBY
  end

  test "registers offense and corrects single-pair multiline hash" do
    assert_correction \
      <<~RUBY,
        x = {
          foo: 1
        }
      RUBY
      <<~RUBY
        x = { foo: 1 }
      RUBY
  end

  test "registers offense and corrects multiline hash keeping a double splat" do
    assert_correction \
      <<~RUBY,
        x = {
          foo: 1,
          **options.slice(:bar, :baz)
        }
      RUBY
      <<~RUBY
        x = { foo: 1, **options.slice(:bar, :baz) }
      RUBY
  end

  test "allows single-line hash" do
    assert_no_offense <<~RUBY
      x = { foo: 1, bar: 2 }
    RUBY
  end

  test "allows multiline hash that would exceed max length" do
    assert_no_offense <<~RUBY
      x = {
        very_long_key_name_here: "very long value that makes this line exceed one hundred and twenty characters easily",
        another_key: "value"
      }
    RUBY
  end

  test "allows multiline hash with multiline pair that cannot collapse" do
    assert_no_offense <<~RUBY
      x = {
        foo: some_very_long_method_name_here(
          very_long_argument_name_one, very_long_argument_name_two, very_long_argument_name_three_that_exceeds
        ),
        bar: 2
      }
    RUBY
  end

  test "registers offense and corrects multiline send with implicit hash" do
    assert_correction \
      <<~RUBY,
        method_call foo: 1,
          bar: 2
      RUBY
      <<~RUBY
        method_call foo: 1, bar: 2
      RUBY
  end

  test "registers offense and corrects multiline array that fits on one line" do
    assert_correction \
      <<~RUBY,
        x = [
          1,
          2,
          3
        ]
      RUBY
      <<~RUBY
        x = [ 1, 2, 3 ]
      RUBY
  end

  test "registers offense and corrects two-element multiline array" do
    assert_correction \
      <<~RUBY,
        x = [
          :foo,
          :bar
        ]
      RUBY
      <<~RUBY
        x = [ :foo, :bar ]
      RUBY
  end

  test "allows single-line array" do
    assert_no_offense <<~RUBY
      x = [ 1, 2, 3 ]
    RUBY
  end

  test "allows multiline array that would exceed max length" do
    assert_no_offense <<~RUBY
      x = [
        "a very long string element that contributes to exceeding the maximum line length when combined together",
        "another long string"
      ]
    RUBY
  end

  test "allows multiline array with multiline element that cannot collapse" do
    assert_no_offense <<~RUBY
      x = [
        some_very_long_method_name(
          very_long_argument_one, very_long_argument_two, very_long_argument_three_that_exceeds_the_line_length_limit
        ),
        2
      ]
    RUBY
  end

  test "allows percent-w array" do
    assert_no_offense <<~RUBY
      x = %w[
        foo
        bar
      ]
    RUBY
  end

  test "registers offense and corrects backslash continuation that fits" do
    assert_correction \
      <<~'RUBY',
        redirect_to \
          users_path
      RUBY
      <<~RUBY
        redirect_to users_path
      RUBY
  end

  test "registers offense and corrects backslash with multiple args" do
    assert_correction \
      <<~'RUBY',
        redirect_to \
          users_path,
          notice: "Done"
      RUBY
      <<~RUBY
        redirect_to users_path, notice: "Done"
      RUBY
  end

  test "registers offense and corrects parenthesized multiline call" do
    assert_correction \
      <<~RUBY,
        User.new(
          name: "John"
        )
      RUBY
      <<~RUBY
        User.new(name: "John")
      RUBY
  end

  test "registers offense and corrects parenthesized call with multiple args" do
    assert_correction \
      <<~RUBY,
        assert_equal(
          "expected",
          actual
        )
      RUBY
      <<~RUBY
        assert_equal("expected", actual)
      RUBY
  end

  test "allows single-line method call" do
    assert_no_offense <<~RUBY
      redirect_to users_path, notice: "Done"
    RUBY
  end

  test "allows multiline method call that would exceed max length" do
    assert_no_offense <<~'RUBY'
      redirect_to \
        very_long_path_helper_method_name,
        notice: "A very long notice message that makes this exceed the maximum line length configured"
    RUBY
  end

  test "allows method call with block" do
    assert_no_offense <<~RUBY
      items.each do |item|
        process(item)
      end
    RUBY
  end

  test "registers offense and corrects single method call on new line" do
    assert_correction \
      <<~RUBY,
        users
          .where(active: true)
      RUBY
      <<~RUBY
        users.where(active: true)
      RUBY
  end

  test "allows long method chain that exceeds max length" do
    assert_no_offense <<~RUBY
      Calendar::EventsMailer
        .with(time_zone: person&.user&.time_zone, locale: person&.user&.locale)
        .attendee_added(self)
        .deliver_later
    RUBY
  end

  test "registers offense and corrects short method chain that fits on one line" do
    assert_correction \
      <<~RUBY,
        users
          .where(active: true)
          .order(:name)
      RUBY
      <<~RUBY
        users.where(active: true).order(:name)
      RUBY
  end

  test "registers offense and corrects chain ending with no-arg method" do
    assert_correction \
      <<~RUBY,
        users
          .active
          .count
      RUBY
      <<~RUBY
        users.active.count
      RUBY
  end

  test "preserves indentation context when collapsing hash" do
    assert_correction \
      <<~RUBY,
        def method
          config = {
            timeout: 30,
            retries: 3
          }
        end
      RUBY
      <<~RUBY
        def method
          config = { timeout: 30, retries: 3 }
        end
      RUBY
  end

  test "allows chain with blocks even if it fits on one line" do
    assert_no_offense <<~RUBY
      items
        .select { it > 0 }
        .count
    RUBY
  end

  test "allows chain ending after multiple blocks" do
    assert_no_offense <<~RUBY
      fields
        .select { address&.public_send(it).blank? }
        .each { record.errors.add(it, :blank) }
        .empty?
    RUBY
  end

  test "allows chain with map block" do
    assert_no_offense <<~RUBY
      slots
        .take_while { it + duration <= to }
        .map { |start_time| Slot.new(start_time) }
    RUBY
  end

  test "registers offense and corrects chain with symbol-to-proc blocks" do
    assert_correction \
      <<~RUBY,
        users
          .select(&:active?)
          .map(&:name)
      RUBY
      <<~RUBY
        users.select(&:active?).map(&:name)
      RUBY
  end

  test "corrects multiline hash inside kwsplat without clobbering" do
    assert_correction \
      <<~RUBY,
        update! **{
          status: "canceled",
          ends_at: Time.current
        }.compact
      RUBY
      <<~RUBY
        update! **{ status: "canceled", ends_at: Time.current }.compact
      RUBY
  end

  test "allows multiline kwsplat hash when suffix pushes line over limit" do
    assert_no_offense <<~RUBY
      class Foo
        def method
          tap do
            unless something
              if condition
                update! **{
                  status: "canceled",
                  ends_at: Time.current,
                  trial_ends_at: (Time.current if trial_ends_at?)
                }.compact
              end
            end
          end
        end
      end
    RUBY
  end

  test "allows multiline hash when suffix would exceed max length" do
    assert_no_offense <<~RUBY
      x = {
        very_long_key: "a value that is long enough to fill",
        another_key: "another value that is moderately long to exceed the limit"
      }.merge(extra).freeze
    RUBY
  end

  test "allows nested multiline hash where inner hash exceeds max length" do
    assert_no_offense <<~RUBY
      x = {
        foo: {
          very_long_key_name_one: "very long value one that contributes to exceeding limit",
          very_long_key_name_two: "very long value two that also contributes to exceeding limit"
        }
      }
    RUBY
  end

  test "allows a multiline literal holding a comment, which one line could not keep" do
    assert_no_offense <<~RUBY
      x = {
        # keep this note
        foo: 1,
        bar: 2
      }
    RUBY
  end

  test "allows a multiline call holding a comment" do
    assert_no_offense <<~RUBY
      User.new(
        # keep this note
        name: "John"
      )
    RUBY
  end
end
