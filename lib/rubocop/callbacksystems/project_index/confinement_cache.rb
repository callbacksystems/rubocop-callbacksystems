# Nested-class confinement analyses shared by every cop investigating the same AST. The weak key lets a completed source
# leave the cache, while graph identity and generation keep an analysis from crossing project revisions.
class RuboCop::Callbacksystems::ProjectIndex::ConfinementCache
  class << self
    def for(nested_class, declaration:, project_index:)
      generation = RuboCop::Callbacksystems::ProjectIndex::Freshness.generation(project_index)
      mutex.synchronize do
        cached = cache[nested_class]

        if cached&.matches?(declaration, project_index, generation:)
          cached.confinement
        else
          confinement = RuboCop::Callbacksystems::ProjectIndex::NestedClassConfinement.new \
            nested_class,
            declaration: declaration,
            project_index: project_index
          cache[nested_class] = Entry.new(declaration.name, project_index, generation, confinement)
          confinement
        end
      end
    end

    private
      def mutex
        @mutex ||= Mutex.new
      end

      def cache
        @cache ||= ObjectSpace::WeakMap.new
      end
  end

  private
    class Entry < Data.define(:declaration_name, :project_index, :generation, :confinement)
      def matches?(other_declaration, other_project_index, generation:)
        declaration_name == other_declaration.name && project_index.equal?(other_project_index) &&
          self.generation == generation
      end
    end
end
