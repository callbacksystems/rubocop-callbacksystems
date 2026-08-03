# The entry point RuboCop asks for when a project lists this gem under `plugins:`. It hands back the cop defaults, and
# the version RuboCop needs in order to resolve pending cops and name the plugin when reporting versions.
class RuboCop::Callbacksystems::Plugin < LintRoller::Plugin
  def about
    LintRoller::About.new \
      name: "rubocop-callbacksystems",
      version: RuboCop::Callbacksystems::VERSION,
      homepage: "https://github.com/callbacksystems/rubocop-callbacksystems",
      description: "Custom cops implementing the Callbacksystems Ruby style guide."
  end

  def supported?(context)
    context.engine == :rubocop
  end

  def rules(_context)
    LintRoller::Rules.new \
      type: :path,
      config_format: :rubocop,
      value: Pathname.new(__dir__).join("../../../config/default.yml")
  end
end
