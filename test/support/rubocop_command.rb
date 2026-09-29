require "open3"

class RuboCopCommand
  def initialize(project)
    @project = project
  end

  def run(*arguments)
    Open3.capture3(
      { "BUNDLE_GEMFILE" => File.expand_path("../../Gemfile", __dir__), "RUBOCOP_OPTS" => nil },
      RbConfig.ruby,
      Gem.bin_path("rubocop", "rubocop"),
      *arguments,
      chdir: project.path
    )
  end

  private
    attr_reader :project
end
