require "digest"

module RuboCop::Callbacksystems::Source::FilesChecksum
  extend self

  def for(patterns, root: Dir.pwd, include_contents: true)
    Contents.new(Array(patterns), File.expand_path(root), include_contents:).checksum
  end

  private
    class Contents
      def initialize(patterns, root, include_contents:)
        @patterns = patterns
        @root = root
        @include_contents = include_contents
      end

      def checksum
        Digest::SHA256.new.tap { |digest| matching.each { append(it, to: digest) } }.hexdigest
      end

      private
        attr_reader :patterns, :root, :include_contents

        def matching
          patterns.flat_map { Dir.glob(File.join(root, it)) }.select { File.file?(it) }.uniq.sort
        end

        def append(path, to:)
          to << relative_path_for(path) << "\0"
          to.file(path) if include_contents?
          to << "\0"
        end

        def relative_path_for(path)
          path.delete_prefix("#{root}/")
        end

        def include_contents?
          include_contents
        end
    end
end
