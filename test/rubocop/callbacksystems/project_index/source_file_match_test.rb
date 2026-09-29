require "test_helper"

class RuboCop::Callbacksystems::ProjectIndex::SourceFileMatchTest < ActiveSupport::TestCase
  include TemporaryProject

  test "for accepts the indexed contents" do
    path = create_file("lib/example.rb", "class Example; end\n")

    assert source_matches?(path:, source: "class Example; end\n")
  end

  test "for shares one file read across cops investigating the same source" do
    source = "class Example; end\n"
    path = create_file("lib/example.rb", source)
    processed_source = RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f, path)
    reads = 0

    with_counted_binread(-> { reads += 1 }) do
      assert RuboCop::Callbacksystems::ProjectIndex::SourceFileMatch.for(processed_source)
      assert RuboCop::Callbacksystems::ProjectIndex::SourceFileMatch.for(processed_source)
    end

    assert_equal 1, reads
  end

  test "for invalidates the shared result when the file changes" do
    source = "class Example; end\n"
    path = create_file("lib/example.rb", source)
    replacement = create_file("lib/replacement.rb", "class Changed; end\n")
    processed_source = RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f, path)
    timestamp = Time.utc(2020, 1, 1)
    File.utime(timestamp, timestamp, path)
    File.utime(timestamp, timestamp, replacement)
    reads = 0

    with_counted_binread(-> { reads += 1 }) do
      assert RuboCop::Callbacksystems::ProjectIndex::SourceFileMatch.for(processed_source)
      File.rename(replacement, path)

      assert_not RuboCop::Callbacksystems::ProjectIndex::SourceFileMatch.for(processed_source)
    end

    assert_equal 2, reads
  end

  test "for keeps different processed source contents separate" do
    source = "class Example; end\n"
    path = create_file("lib/example.rb", source)
    processed_source = RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f, path)
    changed_source = RuboCop::ProcessedSource.new("class Changed; end\n", RUBY_VERSION.to_f, path)
    reads = 0

    with_counted_binread(-> { reads += 1 }) do
      assert RuboCop::Callbacksystems::ProjectIndex::SourceFileMatch.for(processed_source)

      assert_not RuboCop::Callbacksystems::ProjectIndex::SourceFileMatch.for(changed_source)
    end

    assert_equal 2, reads
  end

  test "for rejects an unsaved buffer" do
    path = create_file("lib/example.rb", "class Example; end\n")

    assert_not source_matches?(path:, source: "class Example; def changed; end; end\n")
  end

  test "for rejects a missing file" do
    path = project.path_of("lib/missing.rb")

    assert_not source_matches?(path:, source: "class Missing; end\n")
  end

  test "for rejects a non-UTF-8 current source" do
    source = "# encoding: ISO-8859-1\nNAME = \"caf\xE9\"\n".force_encoding(Encoding::ISO_8859_1)
    path = create_file("lib/example.rb", source)

    assert_not source_matches?(path:, source:)
  end

  test "for rechecks a false result after the file changes" do
    path = create_file("lib/example.rb", "class Example; end\n")
    processed_source = RuboCop::ProcessedSource.new("class Changed; end\n", RUBY_VERSION.to_f, path)
    reads = 0

    with_counted_binread(-> { reads += 1 }) do
      assert_not RuboCop::Callbacksystems::ProjectIndex::SourceFileMatch.for(processed_source)
      assert_not RuboCop::Callbacksystems::ProjectIndex::SourceFileMatch.for(processed_source)
      File.write(path, "class Changed; end\n")

      assert RuboCop::Callbacksystems::ProjectIndex::SourceFileMatch.for(processed_source)
    end

    assert_equal 2, reads
  end

  private
    def source_matches?(path:, source:)
      processed_source = RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f, path)

      RuboCop::Callbacksystems::ProjectIndex::SourceFileMatch.for(processed_source)
    end

    def with_counted_binread(counter)
      original = File.method(:binread)
      File.define_singleton_method(:binread) do |path|
        counter.call
        original.call(path)
      end
      yield
    ensure
      File.define_singleton_method(:binread, original)
    end
end
