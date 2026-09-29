require "fileutils"

class ProjectDirectory
  attr_reader :path

  def initialize(path)
    @path = path
  end

  def create_file(relative_path, contents = "")
    path_of(relative_path).tap do |file|
      FileUtils.mkdir_p File.dirname(file)
      File.write file, contents
    end
  end

  def path_of(relative_path)
    File.join(path, relative_path)
  end

  def remove
    FileUtils.rm_rf path
  end
end
