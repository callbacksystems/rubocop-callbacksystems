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

  test "source_path finds a namespaced gem source from a flat test path" do
    Dir.mktmpdir do |dir|
      File.write("#{dir}/example.gemspec", "")
      FileUtils.mkdir_p("#{dir}/lib/example/commands")
      FileUtils.mkdir_p("#{dir}/test/commands")
      File.write("#{dir}/lib/example/commands/deploy.rb", "class Example::Commands::Deploy; end")

      mapping = RuboCop::Callbacksystems::TestPathMapping.new("#{dir}/test/commands/deploy_test.rb")

      assert_equal "#{dir}/lib/example/commands/deploy.rb", mapping.source_path
    end
  end

  test "gem_project? returns true when a gemspec is present at the root" do
    Dir.mktmpdir do |dir|
      File.write("#{dir}/my_gem.gemspec", "")

      mapping = RuboCop::Callbacksystems::TestPathMapping.new("#{dir}/lib/my_gem.rb")

      assert mapping.gem_project?
    end
  end

  test "gem_project? returns false when no gemspec is present" do
    Dir.mktmpdir do |dir|
      mapping = RuboCop::Callbacksystems::TestPathMapping.new("#{dir}/lib/my_gem.rb")

      assert_not mapping.gem_project?
    end
  end

  test "find_test_file returns existing test file for app path" do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p("#{dir}/test/models")
      File.write("#{dir}/test/models/user_test.rb", "class UserTest; end")

      mapping = RuboCop::Callbacksystems::TestPathMapping.new("#{dir}/app/models/user.rb")

      assert_equal "#{dir}/test/models/user_test.rb", mapping.find_test_file
    end
  end

  test "find_test_file supports the conventional flat test path in a namespaced gem" do
    Dir.mktmpdir do |dir|
      File.write("#{dir}/example.gemspec", "")
      FileUtils.mkdir_p("#{dir}/lib/example/commands")
      FileUtils.mkdir_p("#{dir}/test/commands")
      File.write("#{dir}/test/commands/deploy_test.rb", "class CommandsDeployTest; end")

      mapping = RuboCop::Callbacksystems::TestPathMapping.new("#{dir}/lib/example/commands/deploy.rb")

      assert_equal "#{dir}/test/commands/deploy_test.rb", mapping.find_test_file
    end
  end

  test "find_test_file returns nil when no test file exists" do
    Dir.mktmpdir do |dir|
      mapping = RuboCop::Callbacksystems::TestPathMapping.new("#{dir}/app/models/user.rb")

      assert_nil mapping.find_test_file
    end
  end
end
