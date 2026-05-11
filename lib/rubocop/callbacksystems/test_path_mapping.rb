class RuboCop::Callbacksystems::TestPathMapping
  attr_reader :path

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

  def test_path
    @test_path ||= if path.include?("/app/")
      path.sub("/app/", "/test/").sub(".rb", "_test.rb")
    elsif path.include?("/lib/") && gem_project?
      path.sub("/lib/", "/test/").sub(".rb", "_test.rb")
    end
  end

  def find_test_file
    @find_test_file ||= candidate_test_paths.find { File.exist?(it) }
  end

  private
    def gem_project?
      Dir.glob("#{path.split("/lib/").first}/*.gemspec").any?
    end

    def candidate_test_paths
      lib_test_paths + app_test_paths
    end

    def lib_test_paths
      return [] unless path.match?(%r{(^|/)lib/})

      [
        path.sub(%r{(^|/)lib/(.+)\.rb$}) { "#{Regexp.last_match(1)}test/lib/#{Regexp.last_match(2)}_test.rb" },
        path.sub(%r{(^|/)lib/(.+)\.rb$}) { "#{Regexp.last_match(1)}test/#{Regexp.last_match(2)}_test.rb" }
      ]
    end

    def app_test_paths
      return [] unless path.match?(%r{(^|/)app/})

      [ path.sub(%r{(^|/)app/(.+)\.rb$}) { "#{Regexp.last_match(1)}test/#{Regexp.last_match(2)}_test.rb" } ]
    end
end
