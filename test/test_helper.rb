$VERBOSE = nil

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "active_support"
require "active_support/test_case"
require "rubocop"
require "rubocop-callbacksystems"
require "minitest/autorun"

RuboCop::ConfigLoader.inject_defaults! RuboCop::Callbacksystems::Plugin::CONFIGURATION_PATH

Dir.glob(File.expand_path("support/*.rb", __dir__)).reject { it.end_with?("_test.rb") }.each { require it }
