# The source-to-file comparison shared by every cop investigating one ProcessedSource.
class RuboCop::Callbacksystems::ProjectIndex::SourceFileMatch
  class << self
    def for(processed_source)
      return false unless valid_source?(processed_source.raw_source)

      snapshot = Snapshot.new(processed_source)
      MUTEX.synchronize do
        entry = CACHE[processed_source]

        if entry&.fingerprint == snapshot.fingerprint
          entry.matches
        else
          snapshot.matches?.tap { CACHE[processed_source] = Entry.new(snapshot.fingerprint, it) }
        end
      end
    rescue
      false
    end

    private
      CACHE = ObjectSpace::WeakMap.new
      MUTEX = Mutex.new
      Entry = Data.define(:fingerprint, :matches)

      def valid_source?(source)
        source.encoding == Encoding::UTF_8 && source.valid_encoding?
      end
  end

  private
    class Snapshot
      attr_reader :fingerprint

      def initialize(processed_source)
        @source = processed_source.raw_source
        @path = File.expand_path(processed_source.file_path)
        @file_fingerprint = fingerprint_of(File.stat(path))
        @fingerprint = [ path, file_fingerprint ].freeze
      end

      def matches?
        File.binread(path) == source.b && file_fingerprint == fingerprint_of(File.stat(path))
      end

      private
        attr_reader :source, :path, :file_fingerprint

        def fingerprint_of(stat)
          [ stat.dev, stat.ino, stat.size, *timestamps_of(stat) ].freeze
        end

        def timestamps_of(stat)
          [ stat.mtime.to_i, stat.mtime.nsec, stat.ctime.to_i, stat.ctime.nsec ]
        end
    end
end
