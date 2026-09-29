Gem::Specification.new do |spec|
  spec.name = "rubocop-callbacksystems"
  spec.version = "0.1.0"
  spec.authors = [ "Callback Systems", "Bruno Prieto" ]

  spec.summary = "Callback Systems Ruby style for RuboCop"
  spec.description = "RuboCop cops and shared configuration for the Callback Systems Ruby style in Rails " \
    "applications and Ruby gems."
  spec.homepage = "https://github.com/callbacksystems/rubocop-callbacksystems"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 4.0.0"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["documentation_uri"] = "#{spec.homepage}#readme"
  spec.metadata["default_lint_roller_plugin"] = "RuboCop::Callbacksystems::Plugin"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*", "config/**/*", "docs/**/*", "rubocop.yml", "README.md", "LICENSE"]
    .select { File.file?(it) }
  spec.require_paths = [ "lib" ]

  spec.add_dependency "activesupport", ">= 8.1"
  spec.add_dependency "lint_roller", "~> 1.1"
  spec.add_dependency "rubocop", ">= 1.89"
  spec.add_dependency "rubocop-minitest", ">= 0.40"
  spec.add_dependency "rubocop-performance", ">= 1.26"
  spec.add_dependency "rubocop-rails", ">= 2.36"
  spec.add_dependency "rubydex", "~> 0.4.1"
  spec.add_dependency "zeitwerk", ">= 2.8"
end
