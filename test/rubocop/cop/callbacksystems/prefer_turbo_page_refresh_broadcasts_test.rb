require "test_helper"

class RuboCop::Cop::Callbacksystems::PreferTurboPageRefreshBroadcastsTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PreferTurboPageRefreshBroadcasts

  test "registers offense for broadcasts macro" do
    assert_offense <<~RUBY
      broadcasts
    RUBY
  end

  test "registers offense for broadcasts_to macro" do
    assert_offense <<~RUBY
      broadcasts_to :board
    RUBY
  end

  test "does not mistake broadcasts sent to an object for macros" do
    assert_no_offense <<~RUBY
      radio.broadcasts
      radio.broadcasts_to :listeners
      radio&.broadcasts
    RUBY
  end

  test "registers offense for broadcast_append_to" do
    assert_offense <<~RUBY
      message.broadcast_append_to "messages"
    RUBY
  end

  test "registers offense for broadcast_replace_later_to" do
    assert_offense <<~RUBY
      broadcast_replace_later_to room
    RUBY
  end

  test "registers offense for broadcast_remove_to" do
    assert_offense <<~RUBY
      broadcast_remove_to :board
    RUBY
  end

  test "registers offense for broadcast_render_to" do
    assert_offense <<~RUBY
      broadcast_render_to :board, partial: "messages/message"
    RUBY
  end

  test "registers offense through safe navigation" do
    assert_offense <<~RUBY
      message&.broadcast_prepend_to("messages")
    RUBY
  end

  test "does not register offense for broadcast_refresh_to" do
    assert_no_offense <<~RUBY
      broadcast_refresh_to :board
    RUBY
  end

  test "does not register offense for broadcast_refresh_later_to" do
    assert_no_offense <<~RUBY
      broadcast_refresh_later_to room
    RUBY
  end

  test "does not register offense for broadcasts_refreshes macro" do
    assert_no_offense <<~RUBY
      broadcasts_refreshes
    RUBY
  end

  test "does not register offense for broadcasts_refreshes_to macro" do
    assert_no_offense <<~RUBY
      broadcasts_refreshes_to :board
    RUBY
  end

  test "does not register offense for unrelated broadcast methods" do
    assert_no_offense <<~RUBY
      broadcast_event(:created)
    RUBY
  end
end
