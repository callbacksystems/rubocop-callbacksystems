require "test_helper"

class RuboCop::Callbacksystems::ProjectIndex::ConfinementCacheTest < CopTestCase
  include SourceParsing

  test "for shares an analysis only within the same AST and project index" do
    source = "class Container; class Worker; end; end\n"
    nested_class = processed_source(source).ast.each_node(:class).find { it.identifier.short_name == :Worker }
    first_index = project_index_for("lib/container.rb" => source)
    first = confinements.for(nested_class, declaration: first_index["Container::Worker"], project_index: first_index)

    assert_same first,
      confinements.for(nested_class, declaration: first_index["Container::Worker"], project_index: first_index)

    second_index = project_index_for("lib/container.rb" => source)

    assert_not_same first,
      confinements.for(nested_class, declaration: second_index["Container::Worker"], project_index: second_index)
  end

  test "for refreshes a reused AST when another document introduces an escaping reference" do
    source = "class Container; class Worker; end; end\n"
    other_source = "nil\n"
    index = project_index_for("lib/container.rb" => source, "lib/consumer.rb" => other_source)
    nested_class = processed_source(source).ast.each_node(:class).find { it.identifier.short_name == :Worker }
    first = confinements.for(nested_class, declaration: index["Container::Worker"], project_index: index)
    other_document = RuboCop::ProcessedSource.new(other_source, RUBY_VERSION.to_f, project.path_of("lib/consumer.rb"))

    assert first.confined?
    assert RuboCop::Callbacksystems::ProjectIndex::Freshness.update(index, other_document, "Container::Worker\n")

    refreshed = confinements.for(nested_class, declaration: index["Container::Worker"], project_index: index)

    assert_not_same first, refreshed
    assert_not refreshed.confined?
  end

  private
    def confinements
      RuboCop::Callbacksystems::ProjectIndex::ConfinementCache
    end
end
