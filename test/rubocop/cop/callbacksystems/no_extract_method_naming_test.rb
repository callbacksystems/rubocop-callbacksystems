require "test_helper"

class NoExtractMethodNamingTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoExtractMethodNaming

  test "registers offense for extract_ method name" do
    offenses = assert_offense <<~RUBY
      def extract_job_class_name(node)
      end
    RUBY

    assert_equal 1, offenses.count
    assert_includes offenses.first.message, "job_class_name_for"
  end

  test "no offense for regular method names" do
    assert_no_offense <<~RUBY
      def job_class_name_for(node)
      end
    RUBY
  end

  test "no offense for methods not starting with extract_" do
    assert_no_offense <<~RUBY
      def extracted_data
      end
    RUBY
  end

  test "works with class methods" do
    offenses = assert_offense <<~RUBY
      def self.extract_config(options)
      end
    RUBY

    assert_equal 1, offenses.count
  end
end
