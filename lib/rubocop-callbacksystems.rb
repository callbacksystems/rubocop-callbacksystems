require "zeitwerk"
require "rubocop"
require "active_support/concern"
require "active_support/core_ext/array/access"
require "active_support/core_ext/enumerable"
require "active_support/core_ext/module/delegation"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/string/exclude"
require "active_support/core_ext/string/inflections"

module RubocopCallbacksystems
end

loader = Zeitwerk::Loader.new
loader.tag = "rubocop-callbacksystems"
loader.push_dir("#{__dir__}/rubocop", namespace: RuboCop)
loader.ignore("#{__dir__}/rubocop/callbacksystems/cops_document.rb")
loader.setup
loader.eager_load
RuboCop::ProjectIndexLoader.singleton_class.prepend RuboCop::Callbacksystems::ProjectIndex::Loader
RuboCop::Cop::Team.prepend RuboCop::Callbacksystems::ProjectIndex::Corrections
