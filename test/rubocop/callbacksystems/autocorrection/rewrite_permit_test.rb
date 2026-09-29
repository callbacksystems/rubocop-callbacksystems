require "test_helper"

class RuboCop::Callbacksystems::Autocorrection::RewritePermitTest < ActiveSupport::TestCase
  test "claim grants the first caller and nobody after it" do
    permit = RuboCop::Callbacksystems::Autocorrection::RewritePermit.new

    assert permit.claim
    assert_not permit.claim
  end

  test "claim grants nobody when the permit was not granted" do
    permit = RuboCop::Callbacksystems::Autocorrection::RewritePermit.new(granted: false)

    assert_not permit.claim
  end
end
