require "zeitwerk"
require "rubocop"
require "active_support"
require "active_support/core_ext/array/access"
require "active_support/core_ext/enumerable"
require "active_support/core_ext/module/delegation"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/string/inflections"

module RubocopCallbacksystems
end

loader = Zeitwerk::Loader.new
loader.tag = "rubocop-callbacksystems"
loader.push_dir("#{__dir__}/rubocop", namespace: RuboCop)
loader.setup
loader.eager_load

RuboCop::ConfigLoader.inject_defaults!("#{__dir__}/../config/default.yml")
RuboCop::ConfigObsoletion.files << "#{__dir__}/../config/obsoletion.yml"
