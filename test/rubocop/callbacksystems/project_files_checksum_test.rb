require "test_helper"
require "fileutils"
require "tmpdir"

class ProjectFilesChecksumTest < ActiveSupport::TestCase
  setup { @directory = Dir.mktmpdir }
  teardown { FileUtils.rm_rf(@directory) }

  test "for changes when a matching file changes" do
    write "test/example_test.rb", "test one"

    assert_changes -> { checksum } do
      write "test/example_test.rb", "test two"
    end
  end

  test "for changes when a matching file is added or removed" do
    assert_changes -> { checksum } do
      write "test/example_test.rb", "test one"
    end

    assert_changes -> { checksum } do
      FileUtils.rm File.join(@directory, "test/example_test.rb")
    end
  end

  test "for ignores files outside the declared patterns" do
    assert_no_changes -> { checksum } do
      write "README.md", "documentation"
    end
  end

  private
    def write(relative_path, contents)
      path = File.join(@directory, relative_path)
      FileUtils.mkdir_p File.dirname(path)
      File.write path, contents
    end

    def checksum
      RuboCop::Callbacksystems::ProjectFilesChecksum.for("test/**/*_test.rb", root: @directory)
    end
end
