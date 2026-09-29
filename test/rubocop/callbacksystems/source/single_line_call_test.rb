require "test_helper"

class RuboCop::Callbacksystems::Source::SingleLineCallTest < ActiveSupport::TestCase
  include SourceParsing

  test "fits? returns true for a multiline call short enough for one line" do
    assert call_for(<<~RUBY).fits?
      User.new(
        name: "Bruno"
      )
    RUBY
  end

  test "fits? returns false for a call already on one line" do
    assert_not call_for("User.new(name: \"Bruno\")").fits?
  end

  test "fits? returns false once the one-line form passes the limit" do
    assert_not call_for(<<~RUBY, max_line_length: 20).fits?
      User.new(
        name: "Bruno"
      )
    RUBY
  end

  test "fits? returns false for a call carrying a block" do
    assert_not call_for(<<~RUBY).fits?
      items.each do |item|
        process(item)
      end
    RUBY
  end

  test "fits? returns false for a call carrying a heredoc" do
    assert_not call_for(<<~RUBY).fits?
      execute(
        body: <<~SQL
          select 1
        SQL
      )
    RUBY
  end

  test "fits? returns false when an index call in the chain spans lines" do
    assert_not call_for(<<~RUBY).fits?
      foo[
        1
      ].bar(x)
    RUBY
  end

  test "fits? leaves an inner call to the outer safe-navigation chain" do
    ast = processed_source(<<~RUBY).ast
      user.profile(
        locale
      )&.name
    RUBY

    assert_not RuboCop::Callbacksystems::Source::SingleLineCall.new(ast.receiver, 120).fits?
  end

  test "source joins the arguments onto one line" do
    assert_equal "assert_equal(expected, actual)", call_for(<<~RUBY).source
      assert_equal(
        expected,
        actual
      )
    RUBY
  end

  test "source keeps a receiver chain together" do
    assert_equal "user.profile.update(name: \"Bruno\")", call_for(<<~RUBY).source
      user.profile.update(
        name: "Bruno"
      )
    RUBY
  end

  test "source keeps safe navigation in a mixed receiver chain" do
    assert_equal "user&.profile.update(name: \"Bruno\")", call_for(<<~RUBY).source
      user&.profile.update(
        name: "Bruno"
      )
    RUBY
  end

  test "source keeps safe navigation on the outer call" do
    assert_equal "user.profile&.update(name: \"Bruno\")", call_for(<<~RUBY).source
      user.profile&.update(
        name: "Bruno"
      )
    RUBY
  end

  test "source keeps an index call in the receiver chain as written" do
    assert_equal "foo[1].bar(x)", call_for(<<~RUBY).source
      foo[1].bar(
        x
      )
    RUBY
  end

  test "source drops the parentheses a plain call does not need" do
    assert_equal "redirect_to users_path, notice: \"Done\"", call_for(<<~'RUBY').source
      redirect_to \
        users_path,
        notice: "Done"
    RUBY
  end

  test "source restores the parentheses a builder call needs" do
    assert_equal "User.create(name: \"Bruno\")", call_for(<<~'RUBY').source
      User.create \
        name: "Bruno"
    RUBY
  end

  test "receiver paths walk deeper than Ruby's call stack" do
    root = RuboCop::AST::SendNode.new(:send, [ nil, :root ])
    call = 5_000.times.reduce(root) { |receiver, _| RuboCop::AST::SendNode.new(:send, [ receiver, :next ]) }

    assert_equal 5_001, RuboCop::Callbacksystems::Source::SingleLineCall::ReceiverPath.new(call).count
  end

  test "receiver paths return an enumerator without a block" do
    call = processed_source("user.profile.name").ast
    path = RuboCop::Callbacksystems::Source::SingleLineCall::ReceiverPath.new(call)

    assert_instance_of Enumerator, path.each
    assert_equal %w[ user.profile.name user.profile user ], path.each.map(&:source)
  end

  private
    def call_for(source, max_line_length: 120)
      ast = processed_source(source).ast
      node = ast.call_type? ? ast : ast.each_node(:send, :csend).first

      RuboCop::Callbacksystems::Source::SingleLineCall.new(node, max_line_length)
    end
end
