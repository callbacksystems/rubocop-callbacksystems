class RuboCop::Callbacksystems::Testing::PathMapping
  def initialize(path)
    @path = path
  end

  def source_path
    return @source_path if defined?(@source_path)

    app_path = source_path_in("app")
    lib_path = source_path_in("lib")

    @source_path = if app_path != path && File.exist?(app_path)
      app_path
    elsif lib_path != path && File.exist?(lib_path)
      lib_path
    else
      namespaced_gem_source_path
    end
  end

  def gem_project?
    return @gem_project if defined?(@gem_project)

    @gem_project = Dir.glob(File.join(project_root_path, "*.gemspec")).any?
  end

  def test_path
    return @test_path if defined?(@test_path)

    @test_path = candidate_test_paths.find { File.exist?(it) }
  end

  private
    attr_reader :path

    def source_path_in(directory)
      path.sub(%r{(^|/)test/(.+)_test\.rb$}) do
        "#{Regexp.last_match(1)}#{directory}/#{Regexp.last_match(2)}.rb"
      end
    end

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
      project_directory_match ? matched_project_root : path
    end

    def project_directory_match
      @project_directory_match ||= path.match(%r{\A(?:(.*?)/)?(?:app|lib|test)/})
    end

    def matched_project_root
      project_directory_match.captures.first.to_s.presence || absolute_root
    end

    def absolute_root
      path.start_with?(File::SEPARATOR) ? File::SEPARATOR : ""
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
        candidate = path.sub(%r{(^|/)lib/[^/]+/(.+)\.rb$}) do
          "#{Regexp.last_match(1)}test/#{Regexp.last_match(2)}_test.rb"
        end
        candidate == path ? [] : [ candidate ]
      else
        []
      end
    end

    def app_test_paths
      test_paths_for("app").last(1)
    end
end
