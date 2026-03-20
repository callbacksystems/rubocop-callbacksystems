# Maps between source file paths and test file paths.
# Supports app/ always, and lib/ only in gem projects (detected by .gemspec).
#
# @example
#   TestPathMapping.new("/project/app/models/user.rb").test_path
#   # => "/project/test/models/user_test.rb"
#
#   # In a gem project (has .gemspec):
#   TestPathMapping.new("/gem/lib/payment_gateway.rb").test_path
#   # => "/gem/test/payment_gateway_test.rb"
#
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

  private
    def gem_project?
      root = path.split("/lib/").first
      Dir.glob("#{root}/*.gemspec").any?
    end
end
