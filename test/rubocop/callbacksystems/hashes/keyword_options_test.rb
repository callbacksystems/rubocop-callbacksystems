require "test_helper"

class RuboCop::Callbacksystems::Hashes::KeywordOptionsTest < ActiveSupport::TestCase
  include SourceParsing

  test "known? knows a missing option when no keyword splat is present" do
    assert options_for("route only: :show").known?(:on)
  end

  test "known? cannot know a missing option when a keyword splat is present" do
    assert_not options_for("route **defaults").known?(:on)
  end

  test "known? cannot know a missing option when a dynamic key is present" do
    assert_not options_for("route option_name => :member").known?(:on)
  end

  test "option_for returns the last explicit option" do
    options = options_for("route on: :collection, on: :member")

    assert_equal "on: :member", options.option_for(:on).source
  end

  test "option_for returns nothing when a later keyword splat can replace the option" do
    options = options_for("route on: :member, **defaults")

    assert_nil options.option_for(:on)
  end

  test "option_for returns an explicit option that follows a keyword splat" do
    options = options_for("route **defaults, on: :member")

    assert_equal "on: :member", options.option_for(:on).source
  end

  test "option_for returns nothing when a later dynamic key can replace the option" do
    options = options_for("route on: :member, option_name => :collection")

    assert_nil options.option_for(:on)
  end

  test "option_for returns an explicit option that follows a dynamic key" do
    options = options_for("route option_name => :collection, on: :member")

    assert_equal "on: :member", options.option_for(:on).source
  end

  test "explicit_options_for ignores dynamic keys" do
    options = options_for("route option_name => :collection, on: :member")

    assert_equal [ "on: :member" ], options.explicit_options_for(:on).map(&:source)
  end

  test "elements retain evaluation order across separate hashes" do
    send_node = processed_source("route({ on: :collection }, { **defaults, on: :member })").ast
    options = RuboCop::Callbacksystems::Hashes::KeywordOptions.new(*send_node.arguments.select(&:hash_type?))

    assert_equal [ "on: :collection", "**defaults", "on: :member" ], options.elements.map(&:source)
    assert_equal "on: :member", options.option_for(:on).source
  end

  private
    def options_for(source)
      send_node = processed_source(source).ast

      RuboCop::Callbacksystems::Hashes::KeywordOptions.new(*send_node.arguments.select(&:hash_type?))
    end
end
