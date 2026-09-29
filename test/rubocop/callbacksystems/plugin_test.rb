require "test_helper"

class PluginTest < ActiveSupport::TestCase
  setup { @plugin = RuboCop::Callbacksystems::Plugin.new }

  test "about describes the gem" do
    about = @plugin.about

    assert_equal "rubocop-callbacksystems", about.name
    assert_equal Gem.loaded_specs.fetch("rubocop-callbacksystems").version.to_s, about.version
    assert_predicate about.homepage, :present?
    assert_predicate about.description, :present?
  end

  test "supported? accepts rubocop as the engine" do
    assert @plugin.supported?(LintRoller::Context.new(engine: :rubocop))
    assert_not @plugin.supported?(LintRoller::Context.new(engine: :standard))
  end

  test "rules point at a configuration whose cops are listed alphabetically" do
    assert_equal cop_names.sort, cop_names
  end

  test "rules point at a configuration where every cop opens with its description and whether it ships enabled" do
    configuration.each do |name, settings|
      assert_equal %w[ Description Enabled ], settings.keys.first(2), "#{name} lists its keys out of order"
    end
  end

  test "rules explicitly classify exactly the cops that autocorrect" do
    classified_cops = configuration.filter_map do |name, settings|
      name if settings.key?("SafeAutoCorrect")
    end

    assert_equal autocorrecting_cops.map(&:cop_name).sort, classified_cops.sort

    autocorrecting_cops.each do |cop|
      assert_includes [ true, false ], configuration.fetch(cop.cop_name)["SafeAutoCorrect"],
        "#{cop.cop_name} does not classify its autocorrection"
    end
  end

  test "rules declare the Active Support extension contract in plugin-only use" do
    assert YAML.load_file(RuboCop::Callbacksystems::Plugin::CONFIGURATION_PATH)
      .dig("AllCops", "ActiveSupportExtensionsEnabled")
  end

  test "rules expose safe corrections to safe mode and every correction to all mode" do
    autocorrecting_cops.each do |cop|
      settings = configuration.fetch(cop.cop_name)

      assert_equal settings.fetch("Safe", true) && settings.fetch("SafeAutoCorrect"),
        cop.new(nil, autocorrect: true, safe_autocorrect: true).autocorrect?
      assert_predicate cop.new(nil, autocorrect: true), :autocorrect?
    end
  end

  test "rules reserve named block parameter replacement for unsafe autocorrection" do
    settings = configuration.fetch("Callbacksystems/PreferItBlockParameter")

    assert_not settings.fetch("SafeAutoCorrect")
  end

  test "rules point at the shipped default configuration" do
    rules = @plugin.rules(LintRoller::Context.new(engine: :rubocop))

    assert_equal :path, rules.type
    assert_equal :rubocop, rules.config_format
    assert_equal File.expand_path("../../../config/default.yml", __dir__), rules.value
  end

  private
    def cop_names
      configuration.keys
    end

    def configuration
      YAML.load_file(RuboCop::Callbacksystems::Plugin::CONFIGURATION_PATH)
        .select { |name, _| name.start_with?("Callbacksystems/") }
    end

    def autocorrecting_cops
      RuboCop::Cop::Registry.global.cops.select do |cop|
        cop.department == :Callbacksystems && cop.support_autocorrect?
      end
    end
end
