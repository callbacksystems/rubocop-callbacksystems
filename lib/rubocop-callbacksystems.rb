require "zeitwerk"
require "rubocop"
require "active_support/core_ext/array/access"
require "active_support/core_ext/enumerable"
require "active_support/core_ext/string/inflections"

module RubocopCallbacksystems
  extend self

  def loader
    @loader ||= begin
      loader = Zeitwerk::Loader.new
      loader.tag = "rubocop-callbacksystems"
      loader.push_dir("#{__dir__}/rubocop", namespace: RuboCop)
      loader
    end
  end
end

RubocopCallbacksystems.loader.setup
RubocopCallbacksystems.loader.eager_load
