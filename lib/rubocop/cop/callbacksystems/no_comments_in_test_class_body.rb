# Detects comments in the direct body of test classes. A test explains itself
# through its description, so a comment at the class level is a sentence the
# test names should have carried, and a reader skims past it while looking for
# the test that matters. Comments inside a test block stay allowed for the
# non-obvious why.
#
# There is no fix. Which sentence a comment was carrying is only visible to
# whoever wrote it, so deleting one is the author's call and never ours.
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
  def on_new_investigation
    report_each ClassBodyComments.new(comments_in_test_file, processed_source.ast)
  end

  private
    def comments_in_test_file
      if test_file?(processed_source.file_path)
        prose_comments_in(processed_source)
      else
        []
      end
    end

    class ClassBodyComments
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Avoid comments in test class body. Tests should be self-documenting through descriptive names."

      def initialize(comments, ast)
        @comments = ScopeComments.new(comments, ast)
        @content_scopes = ContentScopes.new(ast)
        @ast = ast
      end

      def each_offense
        test_classes.each do |test_class|
          comments_in_body_of(test_class).each { yield RuboCop::Callbacksystems::Offense.new(it, MESSAGE) }
        end
      end

      private
        attr_reader :comments, :content_scopes, :ast

        def test_classes
          nodes_in(ast, :class).select { test_class?(it) && class_has_content?(it) }
        end

        def test_class?(class_node)
          class_name_of(class_node).end_with?("Test") || rails_test_base_class?(class_node.parent_class)
        end

        def class_has_content?(class_node)
          content_scopes.any_within?(class_node)
        end

        def comments_in_body_of(class_node)
          comments.directly_within(class_node)
        end
    end

    # Comments assigned to the innermost lexical scope containing them with one sweep over scopes and source positions.
    class ScopeComments
      include RuboCop::Callbacksystems::Helpers

      SCOPE_TYPES = [ :class, :module, :sclass, *BLOCK_NODE_TYPES, :def, :defs ]

      def initialize(comments, ast)
        @scopes = nodes_in(ast, *SCOPE_TYPES).sort_by { [ it.source_range.begin_pos, -it.source_range.end_pos ] }
        @scope_index = 0
        @active_scopes = []
        @by_scope = {}.compare_by_identity
        comments.sort_by { it.source_range.begin_pos }.each { assign(it) }
      end

      def directly_within(scope)
        by_scope.fetch(scope) { [] }
      end

      private
        attr_reader :scopes, :active_scopes, :by_scope, :scope_index

        def assign(comment)
          activate_scopes_through(comment.source_range.begin_pos)
          retire_scopes_before(comment.source_range.end_pos)
          (by_scope[active_scopes.last] ||= []) << comment if contained_by_active_scope?(comment)
        end

        def activate_scopes_through(position)
          while next_scope && next_scope.source_range.begin_pos <= position
            retire_scopes_before(next_scope.source_range.begin_pos)
            active_scopes << next_scope
            @scope_index += 1
          end
        end

        def next_scope
          scopes[scope_index]
        end

        def retire_scopes_before(position)
          active_scopes.pop while active_scopes.last&.then { it.source_range.end_pos < position }
        end

        def contained_by_active_scope?(comment)
          active_scopes.last&.source_range&.contains?(comment.source_range)
        end
    end

    # Definitions and blocks indexed by their start, so a class can ask whether its subtree carries test content.
    class ContentScopes
      include RuboCop::Callbacksystems::Helpers

      def initialize(ast)
        @scopes = nodes_in(ast, :any_def, :any_block).sort_by { it.source_range.begin_pos }
      end

      def any_within?(node)
        scope = scopes[first_index_at(node.source_range.begin_pos)]
        scope && node.source_range.contains?(scope.source_range)
      end

      private
        attr_reader :scopes

        def first_index_at(position)
          begin_positions.bsearch_index { it >= position } || scopes.size
        end

        def begin_positions
          @begin_positions ||= scopes.map { it.source_range.begin_pos }
        end
    end
end
