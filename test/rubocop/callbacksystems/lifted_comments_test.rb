require "test_helper"

class LiftedCommentsTest < ActiveSupport::TestCase
  test "lift writes the comments above the statement, at its indentation" do
    processed = processed_source(<<~RUBY)
      class Configuration
        class Error < StandardError
          # explains why this exists
        end
      end
    RUBY
    nested = processed.ast.body

    assert_equal <<~LIFTED, corrected(processed, nested)
      class Configuration
        # explains why this exists
        class Error < StandardError
          # explains why this exists
        end
      end
    LIFTED
  end

  test "lift leaves the source alone when there is nothing to move" do
    processed = processed_source("class Configuration\n  class Error < StandardError; end\nend\n")

    assert_equal processed.buffer.source, corrected(processed, processed.ast.body)
  end

  private
    def processed_source(source)
      RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f, "app/models/report.rb")
    end

    def corrected(processed, node)
      RuboCop::Cop::Corrector.new(processed).then do |corrector|
        comments = RuboCop::Callbacksystems::Helpers.comments_in(node.source_range, processed.comments)
        RuboCop::Callbacksystems::LiftedComments.new(node, comments).lift(corrector)
        corrector.rewrite
      end
    end
end
