require "test_helper"

class RuboCop::Callbacksystems::ProjectIndex::LocationTest < ActiveSupport::TestCase
  Location = Data.define(:uri, :start_line, :start_column, :end_line, :end_column)

  test "for_ast expresses character columns as Rubydex byte columns" do
    source = "\"éé\"; Value\n"
    processed_source = RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f, "example.rb")
    range = processed_source.ast.each_node(:const).first.loc.name

    location = RuboCop::Callbacksystems::ProjectIndex::Location.for_ast(range, uri: "file:///example.rb")

    assert_equal [ "file:///example.rb", 0, 8, 0, 13 ], location.to_h.values
  end

  test "for_rubydex copies an indexed location" do
    location = Location.new("file:///example.rb", 2, 3, 4, 5)

    converted = RuboCop::Callbacksystems::ProjectIndex::Location.for_rubydex(location)

    assert_equal location.to_h, converted.to_h
  end
end
