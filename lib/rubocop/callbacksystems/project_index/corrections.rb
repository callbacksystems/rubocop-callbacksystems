# Keeps the project index synchronized with RuboCop's in-memory autocorrection iterations. RuboCop has no public
# correction lifecycle hook, so this adapter stays at the narrow write boundary and delegates the update itself to an
# object that can fail closed.
module RuboCop::Callbacksystems::ProjectIndex::Corrections
  private
    def apply_correction(processed_source, new_source)
      Correction.new(cops, processed_source, new_source).update_project_index
      super
    end

    class Correction
      def initialize(cops, processed_source, new_source)
        @cops = cops
        @processed_source = processed_source
        @new_source = new_source
      end

      def update_project_index
        if project_index
          RuboCop::Callbacksystems::ProjectIndex::Freshness.update(project_index, processed_source, new_source)
        end
      end

      private
        attr_reader :cops, :processed_source, :new_source

        def project_index
          @project_index ||= indexes.first if indexes.all? { it.equal?(indexes.first) }
        end

        def indexes
          @indexes ||= cops.filter_map(&:project_index)
        end
    end
end
