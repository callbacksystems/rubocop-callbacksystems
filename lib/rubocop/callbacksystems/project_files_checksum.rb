require "digest"

module RuboCop::Callbacksystems::ProjectFilesChecksum
  extend self

  def for(patterns, root: Dir.pwd)
    Digest::SHA256.hexdigest Files.new(Array(patterns), File.expand_path(root)).signature
  end

  private
    class Files
      def initialize(patterns, root)
        @patterns = patterns
        @root = root
      end

      def signature
        matching.map { "#{relative_path_for(it)}\0#{File.binread(it)}\0" }.join
      end

      private
        attr_reader :patterns, :root

        def matching
          patterns.flat_map { Dir.glob(File.join(root, it)) }.select { File.file?(it) }.uniq.sort
        end

        def relative_path_for(path)
          path.delete_prefix("#{root}/")
        end
    end
end
