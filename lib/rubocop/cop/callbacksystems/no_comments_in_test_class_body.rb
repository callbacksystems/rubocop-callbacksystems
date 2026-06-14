# Detects comments in the direct body of test classes.
# Tests should be self-documenting through descriptive test names.
# Comments inside test blocks are allowed if highly relevant.
#
# This cop should only be enabled for test files.
#
# @example
#   # bad - comment at class body level
#   class UserTest < ActiveSupport::TestCase
#     # Setup user fixtures
#     setup do
#       @user = users(:john)
#     end
#
#     test "validates name" do
#       # ...
#     end
#   end
#
#   # good - no comments at class body level
#   class UserTest < ActiveSupport::TestCase
#     setup do
#       @user = users(:john)
#     end
#
#     test "validates name" do
#       # This comment inside test is ok if highly relevant
#     end
#   end
#
class RuboCop::Cop::Callbacksystems::NoCommentsInTestClassBody < RuboCop::Cop::Callbacksystems::Base
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = "Avoid comments in test class body. Tests should be self-documenting through descriptive names."

  def on_new_investigation
    each_offense do |comment, message|
      add_offense(comment, message: message) do |corrector|
        corrector.remove(comment_removal_range_for(comment))
      end
    end
  end

  private
    def each_offense(&block)
      if block
        yield_test_file_offenses(&block) if test_file?
      else
        to_enum(__method__)
      end
    end

    def test_file?
      processed_source.file_path&.end_with?("_test.rb")
    end

    def yield_test_file_offenses(&block)
      processed_source.comments.each do |comment|
        yield comment, MESSAGE if CommentLocation.new(comment, processed_source.ast).offense?
      end
    end

    class CommentLocation
      def initialize(comment, ast)
        @comment = comment
        @ast = ast
      end

      def offense?
        enclosing_class && class_has_content? && !inside_block_or_method?
      end

      private
        attr_reader :comment, :ast

        def enclosing_class
          @enclosing_class ||= ast&.each_node(:class)&.find do |class_node|
            class_node.source_range.contains?(comment.source_range)
          end
        end

        def class_has_content?
          block_or_method_nodes.any?
        end

        def block_or_method_nodes
          @block_or_method_nodes ||= enclosing_class.each_node(:any_block, :any_def).to_a
        end

        def inside_block_or_method?
          block_or_method_nodes.any? { it.source_range.contains?(comment.source_range) }
        end
    end
end
