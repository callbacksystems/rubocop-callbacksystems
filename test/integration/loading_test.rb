require "test_helper"
require "open3"

class LoadingTest < ActiveSupport::TestCase
  test "runtime entrypoint leaves the documentation generator unloaded" do
    output, error, status = Open3.capture3 \
      RbConfig.ruby,
      "-I", File.expand_path("../../lib", __dir__),
      "-e", 'require "rubocop-callbacksystems"; print defined?(RuboCop::Callbacksystems::CopsDocument)'

    assert_predicate status, :success?, error
    assert_empty output
  end
end
