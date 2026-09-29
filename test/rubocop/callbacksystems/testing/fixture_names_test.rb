require "test_helper"

class RuboCop::Callbacksystems::Testing::FixtureNamesTest < ActiveSupport::TestCase
  include TemporaryProject

  test "include? finds a fixture set named after a yml file" do
    assert_includes names_in("test/models/user_test.rb"), :users
  end

  test "include? finds a set nested in a directory under the name Rails gives its accessor" do
    assert_includes names_in("test/models/webhook/delivery_test.rb"), :webhook_deliveries
  end

  test "include? rejects a name no yml file declares" do
    assert_not names_in("test/models/user_test.rb").include?(:sign_in_as)
  end

  test "include? rejects the singular of a set" do
    assert_not names_in("test/models/user_test.rb").include?(:user)
  end

  test "include? rejects what sits under the file fixture directory" do
    assert_not names_in("test/models/user_test.rb").include?(:files_attachment)
  end

  test "include? finds nothing when the tree holds no fixture directory" do
    assert_not names_in(create_file("test/models/user_test.rb")).include?(:users)
  end

  test "include? finds nothing when the file sits outside a test directory" do
    assert_not names_in("app/models/user.rb").include?(:users)
  end

  test "include? finds nothing for a source with no file of its own" do
    assert_not names_in(nil).include?(:users)
  end

  test "include? reads the fixtures of the tree the file belongs to" do
    create_file "engine/test/fixtures/widgets.yml", "one:\n"

    names = names_in(project.path_of("engine/test/models/widget_test.rb"))

    assert_includes names, :widgets
    assert_not names.include?(:users)
  end

  test "include? reads fixture names again for a new investigation" do
    test_file = project.path_of("test/models/widget_test.rb")

    assert_not names_in(test_file, lifetime: Object.new).include?(:widgets)

    create_file "test/fixtures/widgets.yml", "one:\n"

    assert_includes names_in(test_file, lifetime: Object.new), :widgets
  end

  private
    def names_in(test_file, lifetime: nil)
      RuboCop::Callbacksystems::Testing::FixtureNames.new(test_file, lifetime:)
    end
end
