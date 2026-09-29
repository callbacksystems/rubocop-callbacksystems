require "test_helper"

class RuboCop::Callbacksystems::Testing::PathMappingTest < ActiveSupport::TestCase
  include TemporaryProject

  test "source_path gives up when several gem sources match the test path" do
    create_file "gem.gemspec"
    create_file "lib/one/models/user.rb", "class User; end"
    create_file "lib/two/models/user.rb", "class User; end"

    mapping = RuboCop::Callbacksystems::Testing::PathMapping.new(project.path_of("test/models/user_test.rb"))

    assert_nil mapping.source_path
  end

  test "source_path reads a path that names no app, lib or test directory" do
    assert_nil RuboCop::Callbacksystems::Testing::PathMapping.new("user_test.rb").source_path
  end

  test "source_path caches an unresolved mapping" do
    mapping = RuboCop::Callbacksystems::Testing::PathMapping.new(project.path_of("test/models/user_test.rb"))

    assert_nil mapping.source_path

    create_file "app/models/user.rb", "class User; end"

    assert_nil mapping.source_path
  end

  test "source_path maps test to app when app file exists" do
    create_file "app/models/user.rb", "class User; end"

    mapping = RuboCop::Callbacksystems::Testing::PathMapping.new(project.path_of("test/models/user_test.rb"))

    assert_equal project.path_of("app/models/user.rb"), mapping.source_path
  end

  test "source_path falls back to lib when app file does not exist" do
    create_file "lib/models/user.rb", "class User; end"

    mapping = RuboCop::Callbacksystems::Testing::PathMapping.new(project.path_of("test/models/user_test.rb"))

    assert_equal project.path_of("lib/models/user.rb"), mapping.source_path
  end

  test "source_path maps a relative test path to app" do
    create_file "app/models/user.rb", "class User; end"

    Dir.chdir(project.path) do
      mapping = RuboCop::Callbacksystems::Testing::PathMapping.new("test/models/user_test.rb")

      assert_equal "app/models/user.rb", mapping.source_path
    end
  end

  test "source_path maps a relative test path to lib" do
    create_file "lib/models/user.rb", "class User; end"

    Dir.chdir(project.path) do
      mapping = RuboCop::Callbacksystems::Testing::PathMapping.new("test/models/user_test.rb")

      assert_equal "lib/models/user.rb", mapping.source_path
    end
  end

  test "source_path finds a namespaced gem source from a flat test path" do
    create_file "example.gemspec"
    create_file "lib/example/commands/deploy.rb", "class Example::Commands::Deploy; end"

    mapping = RuboCop::Callbacksystems::Testing::PathMapping.new(project.path_of("test/commands/deploy_test.rb"))

    assert_equal project.path_of("lib/example/commands/deploy.rb"), mapping.source_path
  end

  test "source_path reads a gem source sitting straight under lib" do
    create_file "example.gemspec"
    create_file "lib/example.rb", "class Example; end"

    mapping = RuboCop::Callbacksystems::Testing::PathMapping.new(project.path_of("test/example_test.rb"))

    assert_equal project.path_of("lib/example.rb"), mapping.source_path
  end

  test "gem_project? returns true when a gemspec is present at the root" do
    create_file "my_gem.gemspec"

    mapping = RuboCop::Callbacksystems::Testing::PathMapping.new(project.path_of("lib/my_gem.rb"))

    assert mapping.gem_project?
  end

  test "gem_project? returns false when no gemspec is present" do
    mapping = RuboCop::Callbacksystems::Testing::PathMapping.new(project.path_of("lib/my_gem.rb"))

    assert_not mapping.gem_project?
  end

  test "gem_project? caches a negative answer" do
    mapping = RuboCop::Callbacksystems::Testing::PathMapping.new(project.path_of("lib/my_gem.rb"))

    assert_not mapping.gem_project?

    create_file "my_gem.gemspec"

    assert_not mapping.gem_project?
  end

  test "gem_project? keeps the filesystem root distinct from the current directory" do
    mapping = RuboCop::Callbacksystems::Testing::PathMapping.new("/app/models/user.rb")

    assert_equal File::SEPARATOR, mapping.method(:project_root).call
  end

  test "gem_project? does not mistake a parent suffix for a project directory" do
    nested_project = ProjectDirectory.new(Dir.mktmpdir([ "myapp", "lib" ]))
    nested_project.create_file "example.gemspec"

    mapping = RuboCop::Callbacksystems::Testing::PathMapping.new(nested_project.path_of("lib/example.rb"))

    assert mapping.gem_project?
  ensure
    nested_project&.remove
  end

  test "test_path gives nothing for a lib path a gem cannot rewrite" do
    create_file "gem.gemspec"

    assert_nil RuboCop::Callbacksystems::Testing::PathMapping.new(project.path_of("lib/toplevel.rb")).test_path
  end

  test "test_path returns existing test file for app path" do
    create_file "test/models/user_test.rb", "class UserTest; end"

    mapping = RuboCop::Callbacksystems::Testing::PathMapping.new(project.path_of("app/models/user.rb"))

    assert_equal project.path_of("test/models/user_test.rb"), mapping.test_path
  end

  test "test_path maps a relative app path to its test" do
    create_file "test/models/user_test.rb", "class UserTest; end"

    Dir.chdir(project.path) do
      mapping = RuboCop::Callbacksystems::Testing::PathMapping.new("app/models/user.rb")

      assert_equal "test/models/user_test.rb", mapping.test_path
    end
  end

  test "test_path maps a relative lib path to its test" do
    create_file "test/models/user_test.rb", "class UserTest; end"

    Dir.chdir(project.path) do
      mapping = RuboCop::Callbacksystems::Testing::PathMapping.new("lib/models/user.rb")

      assert_equal "test/models/user_test.rb", mapping.test_path
    end
  end

  test "test_path supports the conventional flat test path in a namespaced gem" do
    create_file "example.gemspec"
    create_file "test/commands/deploy_test.rb", "class CommandsDeployTest; end"

    mapping = RuboCop::Callbacksystems::Testing::PathMapping.new(project.path_of("lib/example/commands/deploy.rb"))

    assert_equal project.path_of("test/commands/deploy_test.rb"), mapping.test_path
  end

  test "test_path returns nil when no test file exists" do
    mapping = RuboCop::Callbacksystems::Testing::PathMapping.new(project.path_of("app/models/user.rb"))

    assert_nil mapping.test_path
  end

  test "test_path caches an unresolved mapping" do
    mapping = RuboCop::Callbacksystems::Testing::PathMapping.new(project.path_of("app/models/user.rb"))

    assert_nil mapping.test_path

    create_file "test/models/user_test.rb", "class UserTest; end"

    assert_nil mapping.test_path
  end
end
