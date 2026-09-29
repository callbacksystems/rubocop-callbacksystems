require "test_helper"

class RuboCop::Callbacksystems::Source::FilesChecksumTest < ActiveSupport::TestCase
  include TemporaryProject

  test "for changes when a matching file changes" do
    create_file "test/example_test.rb", "test one"

    assert_changes -> { checksum } do
      create_file "test/example_test.rb", "test two"
    end
  end

  test "for changes when a matching file is added or removed" do
    assert_changes -> { checksum } do
      create_file "test/example_test.rb", "test one"
    end

    assert_changes -> { checksum } do
      FileUtils.rm project.path_of("test/example_test.rb")
    end
  end

  test "for ignores files outside the declared patterns" do
    assert_no_changes -> { checksum } do
      create_file "README.md", "documentation"
    end
  end

  test "for can ignore changes to matching file contents" do
    create_file "test/example_test.rb", "test one"

    assert_no_changes -> { checksum(include_contents: false) } do
      create_file "test/example_test.rb", "test two"
    end
  end

  private
    def checksum(include_contents: true)
      RuboCop::Callbacksystems::Source::FilesChecksum.for("test/**/*_test.rb", root: project.path, include_contents:)
    end
end
