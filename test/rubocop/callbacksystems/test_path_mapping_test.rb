require "test_helper"
require "fileutils"

class RuboCop::Callbacksystems::TestPathMappingTest < ActiveSupport::TestCase
  test "test_file? identifies test files" do
    assert RuboCop::Callbacksystems::TestPathMapping.new("/project/test/models/user_test.rb").test_file?
    assert_not RuboCop::Callbacksystems::TestPathMapping.new("/project/app/models/user.rb").test_file?
  end

  test "source_path maps test to app when app file exists" do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p("#{dir}/app/models")
      File.write("#{dir}/app/models/user.rb", "class User; end")

      mapping = RuboCop::Callbacksystems::TestPathMapping.new("#{dir}/test/models/user_test.rb")

      assert_equal "#{dir}/app/models/user.rb", mapping.source_path
    end
  end

  test "source_path falls back to lib when app file does not exist" do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p("#{dir}/lib/models")
      File.write("#{dir}/lib/models/user.rb", "class User; end")

      mapping = RuboCop::Callbacksystems::TestPathMapping.new("#{dir}/test/models/user_test.rb")

      assert_equal "#{dir}/lib/models/user.rb", mapping.source_path
    end
  end

  test "test_path maps app source path" do
    mapping = RuboCop::Callbacksystems::TestPathMapping.new("/project/app/models/user.rb")

    assert_equal "/project/test/models/user_test.rb", mapping.test_path
  end

  test "test_path maps lib source path in gem project" do
    Dir.mktmpdir do |dir|
      File.write("#{dir}/my_gem.gemspec", "")

      mapping = RuboCop::Callbacksystems::TestPathMapping.new("#{dir}/lib/payment_gateway.rb")

      assert_equal "#{dir}/test/payment_gateway_test.rb", mapping.test_path
    end
  end

  test "test_path returns nil for lib in non-gem project" do
    Dir.mktmpdir do |dir|
      mapping = RuboCop::Callbacksystems::TestPathMapping.new("#{dir}/lib/payment_gateway.rb")

      assert_nil mapping.test_path
    end
  end

  test "test_path handles nested app paths" do
    mapping = RuboCop::Callbacksystems::TestPathMapping.new("/project/app/controllers/public/accounts/checkouts_controller.rb")

    assert_equal "/project/test/controllers/public/accounts/checkouts_controller_test.rb", mapping.test_path
  end

  test "test_path handles nested lib paths in gem project" do
    Dir.mktmpdir do |dir|
      File.write("#{dir}/my_gem.gemspec", "")

      mapping = RuboCop::Callbacksystems::TestPathMapping.new("#{dir}/lib/rubocop/cop/callbacksystems/foo.rb")

      assert_equal "#{dir}/test/rubocop/cop/callbacksystems/foo_test.rb", mapping.test_path
    end
  end

  test "test_path returns nil for non-mappable paths" do
    mapping = RuboCop::Callbacksystems::TestPathMapping.new("/project/config/routes.rb")

    assert_nil mapping.test_path
  end
end
