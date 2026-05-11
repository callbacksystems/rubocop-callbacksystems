Gem::Specification.new do |spec|
  spec.name = "rubocop-callbacksystems"
  spec.version = "0.1.0"
  spec.authors = [ "Callbacksystems" ]
  spec.email = [ "hello@callbacksystems.com" ]

  spec.summary = "Callbacksystems Ruby Style for RuboCop"
  spec.description = "RuboCop configuration and custom cops for Callbacksystems Ruby projects"
  spec.homepage = "https://github.com/callbacksystems/rubocop-callbacksystems"
  spec.required_ruby_version = ">= 4.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*", "config/**/*", "rubocop.yml", "README.md"]
  spec.require_paths = [ "lib" ]

  spec.add_dependency "activesupport"
  spec.add_dependency "rubocop", ">= 1.72"
  spec.add_dependency "rubocop-minitest", ">= 0.36"
  spec.add_dependency "rubocop-performance", ">= 1.24"
  spec.add_dependency "rubocop-rails", ">= 2.29"
  spec.add_dependency "zeitwerk"
end
