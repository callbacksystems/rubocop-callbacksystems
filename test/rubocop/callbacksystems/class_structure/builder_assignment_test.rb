require "test_helper"

class RuboCop::Callbacksystems::ClassStructure::BuilderAssignmentTest < ActiveSupport::TestCase
  test "builds_class_with_body? requires a block carrying code" do
    assert builder_assignment("Entry = Data.define(:name) { def name = super }").builds_class_with_body?
    assert_not builder_assignment("Entry = Data.define(:name)").builds_class_with_body?
    assert_not builder_assignment("Entry = Data.define(:name) {}").builds_class_with_body?
    assert_not builder_assignment("Entry = Data.define(:name) { # marker\n}").builds_class_with_body?
  end

  test "builds_class? recognizes the core class builders" do
    assert builder_assignment("Entry = Data.define(:name)").builds_class?
    assert builder_assignment("Entry = ::Struct.new(:name)").builds_class?
    assert builder_assignment("Entry = Class.new").builds_class?
  end

  test "builds_class? rejects other assignments and namespaced lookalikes" do
    assert_not builder_assignment("Entry = Domain::Data.define(:name)").builds_class?
    assert_not builder_assignment("Entry = Module.new").builds_class?
    assert_not builder_assignment("Entry = :value").builds_class?
  end

  test "builds_class? rejects a non-assignment and an absent node" do
    assert_not builder_assignment("build").builds_class?
    assert_not builder_assignment(nil).builds_class?
  end

  test "builds_module_with_body? requires a block carrying code" do
    assert builder_assignment("Entry = Module.new { def name = :entry }").builds_module_with_body?
    assert_not builder_assignment("Entry = Module.new").builds_module_with_body?
    assert_not builder_assignment("Entry = Module.new {}").builds_module_with_body?
    assert_not builder_assignment("Entry = Module.new { # marker\n}").builds_module_with_body?
  end

  test "builds_module? recognizes only the core Module builder" do
    assert builder_assignment("Entry = ::Module.new").builds_module?
    assert_not builder_assignment("Entry = Domain::Module.new").builds_module?
    assert_not builder_assignment("Entry = Class.new").builds_module?
  end

  private
    def builder_assignment(source)
      processed_source = RuboCop::ProcessedSource.new(source.to_s, RUBY_VERSION.to_f)
      assignment = processed_source.ast&.each_node(:casgn)&.to_a&.last

      RuboCop::Callbacksystems::ClassStructure::BuilderAssignment.new(assignment)
    end
end
