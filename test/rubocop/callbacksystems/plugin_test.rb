require "test_helper"

class RuboCop::Callbacksystems::PluginTest < ActiveSupport::TestCase
  test "about names the gem and the version the gemspec ships" do
    assert_equal "rubocop-callbacksystems", plugin.about.name
    assert_equal gemspec_version, plugin.about.version
  end

  test "supported? is true for RuboCop and false for anything else" do
    assert plugin.supported?(context_for(:rubocop))
    assert_not plugin.supported?(context_for(:standard))
  end

  test "rules points at the config the cops take their defaults from" do
    rules = plugin.rules(context_for(:rubocop))

    assert_equal :path, rules.type
    assert_equal :rubocop, rules.config_format
    assert_path_exists rules.value
    assert_includes YAML.load_file(rules.value).keys, "Callbacksystems/DataClump"
  end

  private
    def plugin
      RuboCop::Callbacksystems::Plugin.new(nil)
    end

    def gemspec_version
      Gem::Specification.load(File.expand_path("../../../rubocop-callbacksystems.gemspec", __dir__)).version.to_s
    end

    def context_for(engine)
      LintRoller::Context.new(engine: engine)
    end
end
