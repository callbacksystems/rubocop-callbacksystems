require "test_helper"

class RuboCop::Callbacksystems::ProjectIndex::ReadingTest < ActiveSupport::TestCase
  include TemporaryProject

  test "checksum reads percent-encoded paths and their contents" do
    path = create_file("lib/café space.rb", "class One; end\n")
    timestamp = Time.utc(2020, 1, 1)
    File.utime(timestamp, timestamp, path)
    original = checksum_for(path)

    File.write(path, "class Two; end\n")
    File.utime(timestamp, timestamp, path)

    assert_equal 15, File.size(path)
    assert_equal timestamp, File.mtime(path)
    assert_not_equal original, checksum_for(path)
  end

  test "checksum tolerates a document disappearing after indexing" do
    path = create_file("lib/example.rb", "class Example; end\n")
    index = project_index_for(path)
    FileUtils.rm(path)

    assert_not_empty checksum_for(index)
  end

  test "reliable? rejects incomplete diagnostics anywhere in the project" do
    {
      "ParseError" => "class Broken\n",
      "DynamicConstantReference" => "namespace = Object\nnamespace::Example\n",
      "DynamicAncestor" => "parent = Object\nclass Example < parent; end\n",
      "DynamicSingletonDefinition" => "target = Object\ndef target.example; end\n"
    }.each do |rule_name, source|
      path = create_file("lib/#{rule_name.underscore}.rb", source)
      index = project_index_for(path)

      assert_includes index.diagnostics.map { it.rule.rule_name }, rule_name
      assert_not RuboCop::Callbacksystems::ProjectIndex::Reading.for(index).reliable?
    end
  end

  test "reliable? rejects opaque constant reflection" do
    RuboCop::Callbacksystems::ProjectIndex::Reading::OPAQUE_CONSTANT_REFLECTIONS.each do |method_name|
      source = "receiver.#{method_name}(:Example)\n"
      path = create_file("lib/#{method_name}.rb", source)
      index = project_index_for(path)

      assert_includes index.method_references.map(&:name), method_name
      assert_not RuboCop::Callbacksystems::ProjectIndex::Reading.for(index).reliable?
    end
  end

  test "reliable? caches opaque reflection" do
    path = create_file("lib/example.rb", "Object.const_get(:Example)\n")
    reading = RuboCop::Callbacksystems::ProjectIndex::Reading.new(project_index_for(path))
    reflection = reading.method(:opaque_reflection?)

    assert reflection.call
    assert reflection.call
  end

  test "reliable? rejects reflective dispatch on a singleton" do
    RuboCop::Callbacksystems::ProjectIndex::Reading::OPAQUE_DISPATCH_METHODS.each do |method_name|
      source = "class Container; end\nContainer.#{method_name}(:const_get, :Example)\n"
      path = create_file("lib/#{method_name}.rb", source)
      index = project_index_for(path)
      reference = index.method_references.find { it.name == method_name }

      assert_instance_of Rubydex::SingletonClass, reference.receiver
      assert_not RuboCop::Callbacksystems::ProjectIndex::Reading.for(index).reliable?
    end
  end

  test "reliable? rejects Marshal object loading" do
    %w[ load restore ].each do |method_name|
      source = "Marshal.#{method_name}(payload)\n"
      path = create_file("lib/#{method_name}.rb", source)
      index = project_index_for(path)

      assert_not RuboCop::Callbacksystems::ProjectIndex::Reading.for(index).reliable?
    end
  end

  test "reliable? accepts an unrelated load method" do
    source = "loader.load(payload)\n"
    path = create_file("lib/loader.rb", source)
    index = project_index_for(path)

    assert RuboCop::Callbacksystems::ProjectIndex::Reading.for(index).reliable?
  end

  test "reliable? accepts receiverless instance dispatch" do
    RuboCop::Callbacksystems::ProjectIndex::Reading::OPAQUE_DISPATCH_METHODS.each do |method_name|
      source = "class Container\n  def process = #{method_name}(:helper)\nend\n"
      path = create_file("lib/#{method_name}.rb", source)
      index = project_index_for(path)
      reference = index.method_references.find { it.name == method_name }

      assert_instance_of Rubydex::Class, reference.receiver
      assert RuboCop::Callbacksystems::ProjectIndex::Reading.for(index).reliable?
    end
  end

  private
    def checksum_for(path_or_index)
      index = path_or_index.is_a?(String) ? project_index_for(path_or_index) : path_or_index

      RuboCop::Callbacksystems::ProjectIndex::Reading.for(index).checksum
    end

    def project_index_for(path)
      flunk("Expected Rubydex to be available") unless RuboCop::ProjectIndexLoader.available?

      RuboCop::ProjectIndexLoader.build_index([ path ]) || flunk("Expected Rubydex to build the project index")
    end
end
