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
class RuboCop::Cop::Callbacksystems::NoCommentsInTestClassBody < RuboCop::Cop::Base
  MESSAGE = "Avoid comments in test class body. Tests should be self-documenting through descriptive names."

  def on_new_investigation
    return unless test_file?

    processed_source.comments.each do |comment|
      add_offense(comment, message: MESSAGE) if CommentLocation.new(comment, processed_source.ast).in_class_body?
    end
  end

  private
    def test_file?
      processed_source.file_path&.end_with?("_test.rb")
    end

    class CommentLocation
      def initialize(comment, ast)
        @comment = comment
        @ast = ast
      end

      def in_class_body?
        enclosing_class && !inside_block_or_method? && class_has_content?
      end

      private
        attr_reader :comment, :ast

        def enclosing_class
          @enclosing_class ||= ast&.each_node(:class)&.find do |class_node|
            class_node.source_range.contains?(comment.source_range)
          end
        end

        def inside_block_or_method?
          enclosing_class.each_node(:block, :def, :defs).any? do |node|
            node.source_range.contains?(comment.source_range)
          end
        end

        def class_has_content?
          enclosing_class.each_node(:block, :def, :defs).any?
        end
    end
end
