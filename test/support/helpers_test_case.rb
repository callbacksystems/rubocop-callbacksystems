require_relative "source_parsing"

class HelpersTestCase < ActiveSupport::TestCase
  include SourceParsing

  Helpers = RuboCop::Callbacksystems::Helpers
end
