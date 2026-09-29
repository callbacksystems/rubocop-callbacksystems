require "digest"

# The source revisions held by a project index while RuboCop autocorrects in memory. RuboCop builds one graph before
# inspecting the project, then may run several corrected versions of a file before writing it. Each accepted revision
# replaces that document in Rubydex; only revisions descended from the indexed disk source are trusted.
class RuboCop::Callbacksystems::ProjectIndex::Freshness
  class << self
    def update(project_index, processed_source, new_source)
      mutex.synchronize do
        RevisionChain.new(
          processed_source, state_for(project_index), project_index:, new_source:
        ).update
      end
    rescue SystemCallError
      false
    end

    def current_source?(project_index, processed_source)
      mutex.synchronize do
        RevisionChain.new(processed_source, state_for(project_index)).current?
      end || false
    rescue SystemCallError
      false
    end

    def reliable?(project_index)
      mutex.synchronize { state_for(project_index).reliable }
    end

    def generation(project_index)
      mutex.synchronize { state_for(project_index).generation }
    end

    private
      def mutex
        @mutex ||= Mutex.new
      end

      def state_for(project_index)
        states[project_index] ||= State.new(0, true, {})
      end

      def states
        @states ||= ObjectSpace::WeakKeyMap.new
      end
  end

  private
    State = Struct.new(:generation, :reliable, :revisions)
    Revision = Data.define(:source, :backing_checksum)

    class RevisionChain
      def initialize(processed_source, state, project_index: nil, new_source: nil)
        @file = RuboCop::Callbacksystems::ProjectIndex::SourceFile.new(processed_source.file_path)
        @source = processed_source.raw_source.b
        @state = state
        @project_index = project_index
        @new_source = new_source
      end

      def update
        backing_checksum ? update_index : false
      end

      def current?
        current_revision? && revision.backing_checksum == disk_checksum
      end

      private
        attr_reader :file, :source, :state, :project_index, :new_source

        def backing_checksum
          @backing_checksum ||= disk_checksum if source_on_disk? || current?
        end

        def source_on_disk?
          disk_checksum == Digest::SHA256.hexdigest(source)
        end

        def disk_checksum
          @disk_checksum ||= Digest::SHA256.file(file.path).hexdigest
        end

        def update_index
          project_index.index_source(file.uri, new_source, "ruby")
          project_index.resolve
          state.revisions[file.path] = Revision.new(new_source.b.dup.freeze, backing_checksum)
          state.generation += 1
          true
        rescue
          state.reliable = false
          state.generation += 1
          false
        end

        def current_revision?
          revision&.source == source
        end

        def revision
          state.revisions[file.path]
        end
    end
end
