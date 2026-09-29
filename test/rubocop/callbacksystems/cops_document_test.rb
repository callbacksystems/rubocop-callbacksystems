require "test_helper"
require "rubocop/callbacksystems/cops_document"

class CopsDocumentTest < ActiveSupport::TestCase
  include TemporaryProject

  setup { @document = RuboCop::Callbacksystems::CopsDocument.new }

  test "save writes the document at its path" do
    document = RuboCop::Callbacksystems::CopsDocument.new(project.path_of("cops.md"))
    document.save

    assert_equal document.text, document.committed
  end

  test "text lists every registered cop" do
    RuboCop::Cop::Registry.global.cops.select { it.department == :Callbacksystems }.each do |cop|
      assert_includes @document.text, "[`#{cop.cop_name}`]"
    end
  end

  test "text marks the cops that autocorrect" do
    assert_includes @document.text,
      "| [`Callbacksystems/PreferDelegate`](../lib/rubocop/cop/callbacksystems/prefer_delegate.rb) | yes |"
    assert_includes @document.text,
      "| [`Callbacksystems/DataClump`](../lib/rubocop/cop/callbacksystems/data_clump.rb) |  |"
  end

  test "committed matches what the generator produces, run bin/docs otherwise" do
    assert_equal @document.text, @document.committed
  end

  test "undescribed is empty because every cop ships a description" do
    assert_empty @document.undescribed
  end
end
