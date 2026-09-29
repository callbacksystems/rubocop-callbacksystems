require "test_helper"

class RuboCop::Callbacksystems::Source::CommentBlocksTest < ActiveSupport::TestCase
  include SourceParsing

  test "each yields consecutive same-column comments as one block" do
    assert_equal [ [ "# one", "# two" ] ], blocks_in(<<~RUBY)
      # one
      # two
      value = 1
    RUBY
  end

  test "each ignores a lone comment line" do
    assert_empty blocks_in(<<~RUBY)
      # alone
      value = 1
    RUBY
  end

  test "each splits blocks separated by code" do
    assert_equal [ [ "# one", "# two" ], [ "# three", "# four" ] ], blocks_in(<<~RUBY)
      # one
      # two
      value = 1
      # three
      # four
      other = 2
    RUBY
  end

  test "each splits blocks at a column change" do
    assert_empty blocks_in(<<~RUBY)
      # one
        # two
      value = 1
    RUBY
  end

  test "each ignores trailing comments" do
    assert_empty blocks_in(<<~RUBY)
      value = 1 # first
      other = 2 # second
    RUBY
  end

  test "each ignores shebangs and magic comments" do
    assert_equal [ [ "# one", "# two" ] ], blocks_in(<<~RUBY)
      #!/usr/bin/env ruby
      # frozen_string_literal: true
      # one
      # two
      value = 1
    RUBY
  end

  test "each ignores directives, which break the block they sit in" do
    assert_equal [ [ "# one", "# two" ] ], blocks_in(<<~RUBY)
      # rubocop:disable Metrics/AbcSize
      # one
      # two
      value = 1
      # rubocop:enable Metrics/AbcSize
    RUBY
  end

  test "each ignores a directive written without a cop name" do
    assert_empty blocks_in(<<~RUBY)
      # rubocop:disable
      # rubocop:todo
      value = 1
    RUBY
  end

  test "each can reject the whole comment run when it contains tooling" do
    source = <<~RUBY
      # steep:ignore:start
      # an explanation that keeps
      # going on the next line
      value = 1
    RUBY

    assert_empty blocks_in(source, reject_tooling_runs: true)
  end

  private
    def blocks_in(source, reject_tooling_runs: false)
      processed = processed_source(source)
      RuboCop::Callbacksystems::Source::CommentBlocks.new(processed, reject_tooling_runs:).map { it.map(&:text) }
    end
end
