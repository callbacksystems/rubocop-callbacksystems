require "test_helper"

class RuboCop::Cop::Callbacksystems::CommentBlockLengthTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::CommentBlockLength

  test "allows a two-line block inside a class body" do
    assert_no_offense <<~RUBY
      class Widget
        # A cache miss means the nightly job never ran, so we raise
        # to surface the broken schedule instead of recomputing.
        def price
        end
      end
    RUBY
  end

  test "allows a four-line block immediately above a top-level class" do
    assert_no_offense <<~RUBY
      # The importer keeps the raw payload because support reads it
      # when a row is disputed.
      # Rows are matched by external id, so a rename upstream never
      # duplicates a record here.
      class Widget
      end
    RUBY
  end

  test "allows a three-line block immediately above a top-level module" do
    assert_no_offense <<~RUBY
      # The registry is populated at boot.
      # Entries are frozen, so lookups
      # never race with writes.
      module Widgets
      end
    RUBY
  end

  test "allows a lone comment line" do
    assert_no_offense <<~RUBY
      class Widget
        # A cache miss means the nightly job never ran.
        def price
        end
      end
    RUBY
  end

  test "allows trailing comments" do
    assert_no_offense <<~RUBY
      class Widget
        def price # first
        end # second
        def name # third
        end # fourth
      end
    RUBY
  end

  test "allows a five-line block inside a test block" do
    assert_no_offense <<~RUBY
      class WidgetTest < ActiveSupport::TestCase
        test "price" do
          # The widget starts without a price.
          # The nightly job then sets one.
          # A second run must not touch it.
          # We run the job twice here.
          # Then we read the price back.
          assert_equal 1, widget.price
        end
      end
    RUBY
  end

  test "allows long comment blocks inside each of many test blocks" do
    tests = 100.times.map do |number|
      <<~RUBY
        test "case #{number}" do
          # First scenario line.
          # Second scenario line.
          # Third scenario line.
          run
        end
      RUBY
    end.join

    assert_no_offense "class WidgetTest < ActiveSupport::TestCase\n#{tests}end\n"
  end

  test "does not count shebangs and magic comments toward a block" do
    assert_no_offense <<~RUBY
      #!/usr/bin/env ruby
      # frozen_string_literal: true
      # one line of prose here
      # and a second one.
      value = 1
    RUBY
  end

  test "registers offense for a three-line block inside a class body" do
    offenses = assert_offense <<~RUBY
      class Widget
        # The cache is warmed by the nightly job, and a miss here
        # means the job never ran, so we raise instead of recomputing
        # to surface the broken schedule.
        def price
        end
      end
    RUBY

    assert_includes offenses.first.message, "spans 3 lines where 2 is the limit"
  end

  test "registers offense for a five-line block above a top-level class" do
    offenses = assert_offense <<~RUBY
      # One line of prose.
      # Two lines of prose.
      # Three lines of prose.
      # Four lines of prose.
      # Five lines of prose.
      class Widget
      end
    RUBY

    assert_includes offenses.first.message, "spans 5 lines where 4 is the limit"
  end

  test "registers offense for a five-line block inside a private helper method of a test class" do
    offenses = assert_offense <<~RUBY
      class WidgetTest < ActiveSupport::TestCase
        test "price" do
          assert_equal 1, widget.price
        end

        private
          def widget
            # The widget starts without a price.
            # The nightly job then sets one.
            # A second run must not touch it.
            # We run the job twice here.
            # Then we read the price back.
            Widget.new
          end
      end
    RUBY

    assert_includes offenses.first.message, "spans 5 lines where 2 is the limit"
  end

  test "registers offense for a five-line block inside a setup block" do
    assert_offense <<~RUBY
      class WidgetTest < ActiveSupport::TestCase
        setup do
          # The widget starts without a price.
          # The nightly job then sets one.
          # A second run must not touch it.
          # We run the job twice here.
          # Then we read the price back.
          @widget = Widget.new
        end
      end
    RUBY
  end

  test "registers offense for a three-line block above a nested class" do
    assert_offense <<~RUBY
      class Widget
        # The part list is memoized because
        # the catalog lookup crosses the
        # network on every call.
        class Part
        end
      end
    RUBY
  end

  test "registers offense for a three-line block separated from the class by a blank line" do
    assert_offense <<~RUBY
      # One line of prose.
      # Two lines of prose.
      # Three lines of prose.

      class Widget
      end
    RUBY
  end

  test "registers offense for a three-line block above plain top-level code" do
    assert_offense <<~RUBY
      # One line of prose.
      # Two lines of prose.
      # Three lines of prose.
      value = 1
    RUBY
  end
end
