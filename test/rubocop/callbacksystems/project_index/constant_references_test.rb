require "test_helper"

class RuboCop::Callbacksystems::ProjectIndex::ConstantReferencesTest < ActiveSupport::TestCase
  include TemporaryProject

  test "for reuses one reading of the same project graph" do
    project_index = index_for("lib/example.rb" => "class Example; end\n")

    first = RuboCop::Callbacksystems::ProjectIndex::ConstantReferences.for(project_index)

    assert_same first, RuboCop::Callbacksystems::ProjectIndex::ConstantReferences.for(project_index)
  end

  test "for does not reuse a reading for a different project graph" do
    first_index = index_for("lib/first.rb" => "class First; end\n")
    second_index = index_for("lib/second.rb" => "class Second; end\n")

    first = RuboCop::Callbacksystems::ProjectIndex::ConstantReferences.for(first_index)
    second = RuboCop::Callbacksystems::ProjectIndex::ConstantReferences.for(second_index)

    assert_not_same first, second
  end

  test "referenced declaration ignores the singleton companion of a call receiver" do
    source = <<~RUBY
      class Report
        class Cell
        end

        def build
          Cell.new
        end
      end
    RUBY
    references, ast = references_and_ast_for(source)
    declaration = references.referenced_declaration_for(ast.each_node(:const).to_a.last)

    assert_instance_of Rubydex::Class, declaration
    assert_equal "Report::Cell", declaration.name
  end

  test "referenced declaration maps the last segment of a qualified constant" do
    source = <<~RUBY
      class Report
        class Cell
        end

        def build
          Report::Cell
        end
      end
    RUBY
    references, ast = references_and_ast_for(source)
    constant = ast.each_node(:const).find { it.source == "Report::Cell" }

    assert_equal "Report::Cell", references.referenced_declaration_for(constant).name
  end

  test "referenced declaration returns nothing for an unresolved constant" do
    references, ast = references_and_ast_for("MissingConstant\n")

    assert_nil references.referenced_declaration_for(ast)
  end

  test "within maps parser character columns and escaped paths to Rubydex locations" do
    source = <<~RUBY
      class Report
        class Cell
        end

        def build
          label = "é"; Cell.new
        end
      end
    RUBY
    references, ast = references_and_ast_for(source, file: "lib/project files/example.rb")
    declaration = references.referenced_declaration_for(ast.each_node(:const).to_a.last)

    assert_equal "Report::Cell", declaration.name
  end

  test "declaration named resolves relative qualified names through lexical nesting" do
    source = <<~RUBY
      module Outer
        class Inner
          class Target
            class Leaf
            end
          end

          def value
            Outer::Inner::Target::Leaf
          end
        end
      end
    RUBY
    references, ast = references_and_ast_for(source)
    constant = ast.each_node(:const).find { it.source == "Outer::Inner::Target::Leaf" }
    declaration = references.declaration_named("Target::Leaf", beside: constant)

    assert_equal "Outer::Inner::Target::Leaf", declaration.name
    assert_same declaration, references.declaration_named("Target::Leaf", beside: constant)
  end

  test "declaration named resolves an absolute name from Object" do
    source = <<~RUBY
      class Target
      end

      module Outer
        class Target
        end

        def value
          Outer::Target
        end
      end
    RUBY
    references, ast = references_and_ast_for(source)
    constant = ast.each_node(:const).find { it.source == "Outer::Target" }

    assert_equal "Target", references.declaration_named("::Target", beside: constant).name
    assert_equal "Outer::Target", references.declaration_named("Target", beside: constant).name
  end

  test "declaration named excludes an unopened class from identifier and superclass resolution" do
    source = <<~RUBY
      module Outer
        class Parent
        end

        class Child < Parent
          class Parent
          end
        end
      end
    RUBY
    references, ast = references_and_ast_for(source)
    child = ast.each_node(:class).find { it.identifier.const_name == "Child" }

    assert_equal "Outer::Parent", references.declaration_named("Parent", beside: child.identifier).name
    assert_equal "Outer::Parent", references.declaration_named("Parent", beside: child.parent_class).name
  end

  test "declaration named returns nothing when Rubydex cannot resolve the name" do
    references, ast = references_and_ast_for("Example = Object.new\n")

    assert_nil references.declaration_named("Missing", beside: ast)
  end

  test "declaration named returns nothing when the graph rejects a resolution" do
    source = "Example = Object.new\n"
    path = create_file("lib/example.rb", source)
    processed_source = RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f, path)
    project_index = Object.new
    project_index.define_singleton_method(:constant_references) { [] }
    project_index.define_singleton_method(:resolve_constant) { |*| raise "unavailable" }
    references = RuboCop::Callbacksystems::ProjectIndex::ConstantReferences.new(project_index).within(processed_source)

    assert_nil references.declaration_named("Example", beside: processed_source.ast)
  end

  private
    def index_for(sources)
      build_index(sources.map { |path, source| create_file(path, source) })
    end

    def build_index(paths)
      flunk("Expected Rubydex to be available") unless RuboCop::ProjectIndexLoader.available?

      RuboCop::ProjectIndexLoader.build_index(paths) || flunk("Expected Rubydex to build the project index")
    end

    def references_and_ast_for(source, file: "lib/example.rb")
      path = create_file(file, source)
      project_index = build_index([ path ])
      processed_source = RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f, path)

      [ RuboCop::Callbacksystems::ProjectIndex::ConstantReferences.for(project_index).within(processed_source),
        processed_source.ast ]
    end
end
