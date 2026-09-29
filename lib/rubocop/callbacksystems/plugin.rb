require "lint_roller"

class RuboCop::Callbacksystems::Plugin < LintRoller::Plugin
  GEM_NAME = "rubocop-callbacksystems"
  CONFIGURATION_PATH = File.expand_path("../../../config/default.yml", __dir__)

  def about
    LintRoller::About.new \
      name: specification.name,
      version: specification.version.to_s,
      homepage: specification.homepage,
      description: specification.summary
  end

  def supported?(context)
    context.engine == :rubocop
  end

  def rules(context)
    LintRoller::Rules.new(type: :path, config_format: :rubocop, value: CONFIGURATION_PATH)
  end

  private
    def specification
      @specification ||= Gem.loaded_specs.fetch(GEM_NAME)
    end
end
