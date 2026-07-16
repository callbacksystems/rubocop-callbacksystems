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
      elsif lib_path != path && File.exist?(lib_path)
        lib_path
      else
        namespaced_gem_source_path
      end
    end
  end

  def gem_project?
    Dir.glob(File.join(project_root_path, "*.gemspec")).any?
  end

  def find_test_file
    @find_test_file ||= candidate_test_paths.find { File.exist?(it) }
  end

  private
    attr_reader :path

    def namespaced_gem_source_path
      if gem_project? && path.match?(%r{(^|/)test/.+_test\.rb$})
        relative_source = path.match(%r{(^|/)test/(.+)_test\.rb$}).captures.second
        candidates = Dir.glob(File.join(project_root_path, "lib", "*", "#{relative_source}.rb"))
        candidates.one? ? candidates.first : nil
      end
    end

    def project_root_path
      project_root.empty? ? "." : project_root
    end

    def project_root
      path.match(%r{\A(.*?)(?:/)?(?:app|lib|test)/})&.captures&.first || path
    end

    def candidate_test_paths
      lib_test_paths + flat_gem_test_paths + app_test_paths
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

    def flat_gem_test_paths
      if gem_project?
        candidate = path.sub(%r{(^|/)lib/[^/]+/(.+)\.rb$}) { "#{Regexp.last_match(1)}test/#{Regexp.last_match(2)}_test.rb" }
        candidate == path ? [] : [ candidate ]
      else
        []
      end
    end

    def app_test_paths
      test_paths_for("app").last(1)
    end
end
