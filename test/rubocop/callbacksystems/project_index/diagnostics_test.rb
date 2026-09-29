require "test_helper"

class RuboCop::Callbacksystems::ProjectIndex::DiagnosticsTest < ActiveSupport::TestCase
  Rule = Data.define(:rule_name)
  Location = Data.define(:uri, :start_line, :start_column, :end_line, :end_column)
  Diagnostic = Data.define(:rule, :location)
  Definition = Data.define(:location)
  ProjectIndex = Data.define(:diagnostics)

  test "for reuses the reading of one project index" do
    project_index = ProjectIndex.new([])

    assert_same diagnostics_for(project_index), diagnostics_for(project_index)
    assert_not_same diagnostics_for(project_index), diagnostics_for(ProjectIndex.new([]))
  end

  test "any_named? recognizes a diagnostic anywhere in the index" do
    diagnostics = diagnostics_for ProjectIndex.new([ diagnostic("ParseError", "file:///broken.rb") ])

    assert diagnostics.any_named?("ParseError")
    assert_not diagnostics.any_named?("DynamicAncestor")
  end

  test "within_definitions? finds diagnostics contained by a definition" do
    diagnostics = diagnostics_for ProjectIndex.new([
      diagnostic("DynamicAncestor", "file:///models.rb", line: 2),
      diagnostic("ParseError", "file:///models.rb", line: 8),
      diagnostic("DynamicAncestor", "file:///other.rb", line: 2)
    ])
    definition = Definition.new(location("file:///models.rb", start_line: 1, end_line: 4))

    assert diagnostics.within_definitions?([ definition ], named: [ "DynamicAncestor" ])
    assert_not diagnostics.within_definitions?([ definition ], named: [ "ParseError" ])
    assert_not diagnostics.within_definitions?([], named: [ "DynamicAncestor" ])
  end

  test "within_definitions? ignores a named diagnostic in another URI" do
    diagnostics = diagnostics_for ProjectIndex.new([ diagnostic("DynamicAncestor", "file:///other.rb", line: 2) ])
    definition = Definition.new(location("file:///models.rb", start_line: 1, end_line: 4))

    assert_not diagnostics.within_definitions?([ definition ], named: [ "DynamicAncestor" ])
  end

  private
    def diagnostics_for(project_index)
      RuboCop::Callbacksystems::ProjectIndex::Diagnostics.for(project_index)
    end

    def diagnostic(rule_name, uri, line: 1)
      Diagnostic.new(Rule.new(rule_name), location(uri, start_line: line, end_line: line))
    end

    def location(uri, start_line:, end_line: start_line)
      Location.new(uri, start_line, 0, end_line, 10)
    end
end
