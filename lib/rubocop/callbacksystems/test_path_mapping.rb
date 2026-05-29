class RuboCop::Callbacksystems::TestPathMapping
  def initialize(path)
    @path = path
  end

  def test_file?
    path.include?("/test/") && path.end_with?("_test.rb")
  end

  def source_path
    @source_path ||= begin
      app_path = path.sub("/test/", "/app/").sub("_test.rb", ".rb")
      lib_path = path.sub("/test/", "/lib/").sub("_test.rb", ".rb")

      if app_path != path && File.exist?(app_path)
        app_path
      elsif lib_path != path
        lib_path
      end
    end
  end

  def gem_project?
    Dir.glob("#{project_root}/*.gemspec").any?
  end

  def find_test_file
    @find_test_file ||= candidate_test_paths.find { File.exist?(it) }
  end

  private
    attr_reader :path

    def project_root
      path.split("/lib/").first
    end

    def candidate_test_paths
      lib_test_paths + app_test_paths
    end

    def lib_test_paths
      test_paths_for("lib")
    end

    def test_paths_for(root)
      if path.match?(%r{(^|/)#{root}/})
        [ rewrite(root, "test/#{root}/"), rewrite(root, "test/") ]
      else
        []
      end
    end

    def rewrite(root, prefix)
      path.sub(%r{(^|/)#{root}/(.+)\.rb$}) { "#{Regexp.last_match(1)}#{prefix}#{Regexp.last_match(2)}_test.rb" }
    end

    def app_test_paths
      test_paths_for("app").last(1)
    end
end
