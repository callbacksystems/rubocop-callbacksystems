require "test_helper"

class RuboCop::Callbacksystems::ProjectIndex::NestedClassMethodDispatchTest < ActiveSupport::TestCase
  include SourceParsing
  include TemporaryProject

  test "confined? accepts calls owned by the nested class" do
    assert dispatch_of(<<~RUBY).confined?
      class Container
        class Worker
          def run
            finish
          end

          def finish; end
        end
      end
    RUBY
  end

  test "confined? accepts singleton calls owned by the nested class" do
    assert dispatch_of(<<~RUBY).confined?
      class Container
        class Worker
          def self.build
            finish
          end

          def self.finish; end
        end
      end
    RUBY
  end

  test "confined? rejects inherited calls" do
    assert_not dispatch_of(<<~RUBY).confined?
      class Object
        def publish; end
      end

      class Container
        class Worker
          def run
            publish
          end
        end
      end
    RUBY
  end

  test "confined? rejects super calls" do
    assert_not dispatch_of(<<~RUBY).confined?
      class Container
        class Worker
          def run
            super
          end
        end
      end
    RUBY
  end

  test "confined? ignores calls owned by a class nested within the nested class" do
    assert dispatch_of(<<~RUBY).confined?
      class Container
        class Worker
          class Detail
            def run
              inherited_method
            end
          end
        end
      end
    RUBY
  end

  test "confined? ignores calls owned by a singleton class for an expression" do
    assert dispatch_of(<<~RUBY).confined?
      class Container
        class Worker
          class << Object.new
            def run
              inherited_method
            end
          end
        end
      end
    RUBY
  end

  private
    def dispatch_of(source)
      path = create_file("lib/container.rb", source)
      flunk("Expected Rubydex to be available") unless RuboCop::ProjectIndexLoader.available?
      project_index = RuboCop::ProjectIndexLoader.build_index([ path ]) || flunk("Expected a project index")
      nested_class = processed_source(source).ast.each_node(:class).find { it.identifier.short_name == :Worker }

      RuboCop::Callbacksystems::ProjectIndex::NestedClassMethodDispatch.new \
        nested_class,
        declaration: project_index["Container::Worker"]
    end
end
