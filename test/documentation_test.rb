require "test_helper"
require "audits/cop_reference"

class DocumentationTest < ActiveSupport::TestCase
  test "the cop reference matches the cops that ship" do
    assert_generated CopReference::DOCUMENT_PATH, reference.document
  end

  test "the shipped config carries each cop's description" do
    assert_generated CopReference::CONFIG_PATH, reference.configured
  end

  test "every cop's header opens with a sentence describing it" do
    undescribed = reference.cops.reject { it.description.end_with?(".") }.map(&:name)

    assert_empty undescribed, "start each cop's file with a comment saying what it is for"
  end

  test "no cop opens with a sentence too long to read as a summary" do
    rambling = reference.cops.select { it.description.length > MAX_DESCRIPTION }.map(&:name)

    assert_empty rambling, "open with a short sentence and leave the rest to the paragraph below it"
  end

  private
    HINT = "run `UPDATE_DOCS=1 bin/test` and review the diff"
    MAX_DESCRIPTION = 140

    def assert_generated(path, expected)
      full_path = File.join(CopReference::ROOT, path)
      File.write(full_path, expected) if ENV["UPDATE_DOCS"]

      assert_equal expected, File.read(full_path), "#{path} is out of date, #{HINT}"
    end

    def reference
      @reference ||= CopReference.new
    end
end
