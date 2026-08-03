require "zeitwerk"
require "lint_roller"
require "rubocop"
require "active_support"
require "active_support/core_ext/array/access"
require "active_support/core_ext/enumerable"
require "active_support/core_ext/module/delegation"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/string/inflections"

require_relative "rubocop/callbacksystems/version"

module RubocopCallbacksystems
end

loader = Zeitwerk::Loader.new
loader.tag = "rubocop-callbacksystems"
loader.push_dir("#{__dir__}/rubocop", namespace: RuboCop)
loader.ignore("#{__dir__}/rubocop/callbacksystems/version.rb")
loader.setup
loader.eager_load

RuboCop::ConfigObsoletion.files << "#{__dir__}/../config/obsoletion.yml"
