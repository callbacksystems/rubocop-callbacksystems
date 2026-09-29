# Resolved constant references from Rubydex, indexed once by their exact source location so AST readers can ask which
# declaration a constant names without rebuilding or walking the project graph.
class RuboCop::Callbacksystems::ProjectIndex::ConstantReferences
  extend RuboCop::Callbacksystems::ProjectIndex::Cache

  def within(processed_source)
    Source.new \
      project_index,
      references_by_location,
      RuboCop::Callbacksystems::ProjectIndex::SourceFile.new(processed_source.file_path).uri
  end

  private
    attr_reader :project_index

    def initialize(project_index)
      @project_index = project_index
    end

    def references_by_location
      @references_by_location ||= project_index.constant_references.grep(Rubydex::ResolvedConstantReference)
        .group_by { RuboCop::Callbacksystems::ProjectIndex::Location.for_rubydex(it.location) }
    end

    # The references and resolver belonging to one source file.
    class Source
      include RuboCop::Cop::ProjectIndexHelp

      def initialize(project_index, references_by_location, uri)
        @project_index = project_index
        @references_by_location = references_by_location
        @uri = uri
      end

      def referenced_declaration_for(constant_node)
        declarations_at(constant_node.loc.name).grep_v(Rubydex::SingletonClass)
          .uniq(&:name).then { it.first if it.one? }
      end

      def declaration_named(name, beside:)
        nesting = name.to_s.start_with?("::") ? [] : lexical_nesting_of(beside)
        query = Resolution.new(name.to_s, nesting)

        resolutions.fetch(query) { resolutions[query] = query.declaration_in(project_index) }
      end

      private
        attr_reader :project_index, :references_by_location, :uri

        def declarations_at(range)
          location = RuboCop::Callbacksystems::ProjectIndex::Location.for_ast(range, uri:)
          references_by_location.fetch(location) { [] }.map(&:declaration)
        end

        def resolutions
          @resolutions ||= {}
        end

        class Resolution < Data.define(:name, :nesting)
          def declaration_in(project_index)
            segments.drop(1).reduce(project_index.resolve_constant(segments.first, nesting)) do |declaration, segment|
              declaration.find_member(segment) if declaration.is_a?(Rubydex::Namespace)
            end
          rescue
            nil
          end

          private
            def segments
              name.delete_prefix("::").split("::")
            end
        end
    end
end
