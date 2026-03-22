require "test_helper"

class RuboCop::Callbacksystems::TestCopHelpersTest < CopTestCase
  test "included defines test_block? matcher on including class" do
    assert_respond_to TestCop.new, :test_block?
  end

  private
    class TestCop < RuboCop::Cop::Base
      include RuboCop::Callbacksystems::TestCopHelpers
    end
end
