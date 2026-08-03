Gem::Specification.new do |spec|
  spec.name = "rubocop-callbacksystems"
  spec.version = "0.1.0"
  spec.authors = [ "Callbacksystems" ]
  spec.email = [ "hello@callbacksystems.com" ]

  spec.summary = "Shared RuboCop configuration for Callback Systems projects"
  spec.description = <<~DESC.strip
    A RuboCop plugin whose cops cover what RuboCop core and the official plugins
    do not: naming and structural conventions, declarative style, test
    discipline, and the patterns that keep code readable as a system grows.
  DESC
  spec.homepage = "https://github.com/callbacksystems/rubocop-callbacksystems"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 4.0.0"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["documentation_uri"] = "#{spec.homepage}/blob/main/docs/README.md"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["default_lint_roller_plugin"] = "RuboCop::Callbacksystems::Plugin"

  spec.files = Dir["lib/**/*", "config/**/*", "rubocop.yml", "README.md", "CHANGELOG.md", "LICENSE"]
  spec.require_paths = [ "lib" ]

  spec.add_dependency "activesupport"
  spec.add_dependency "lint_roller", "~> 1.1"
  spec.add_dependency "rubocop", ">= 1.72", "< 2.0"
  spec.add_dependency "rubocop-minitest", ">= 0.36"
  spec.add_dependency "rubocop-performance", ">= 1.24"
  spec.add_dependency "rubocop-rails", ">= 2.29"
  spec.add_dependency "zeitwerk"
end
