require "test_helper"

class RuboCop::Callbacksystems::ProjectIndex::LoaderTest < ActiveSupport::TestCase
  include TemporaryProject

  test "build_index supplements and registers every requested Ruby source" do
    paths = [
      create_file("Gemfile", "class GemfileDeclaration; end\n"),
      create_file("lib/example.rb", "class Example; end\n")
    ]

    flunk("Expected Rubydex to be available") unless RuboCop::ProjectIndexLoader.available?
    index = RuboCop::ProjectIndexLoader.build_index(paths)

    assert_predicate index["GemfileDeclaration"], :itself
    assert_predicate index["Example"], :itself
    assert RuboCop::Callbacksystems::ProjectIndex::Coverage.complete?(index)
  end

  test "build_index leaves an unavailable project index alone" do
    loader = Object.new
    loader.define_singleton_method(:build_index) { |_paths| nil }
    loader.singleton_class.prepend RuboCop::Callbacksystems::ProjectIndex::Loader

    assert_nil loader.build_index([])
  end
end
