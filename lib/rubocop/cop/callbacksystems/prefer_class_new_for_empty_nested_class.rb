# A nested class with no body declares that something exists, most often an
# error. Written as a constant it says so in one line and stops looking like a
# class that lost its body.
#
# Only nested definitions are reported. A class living in its own file is that
# file's subject, and `class` reads as the heading it is.
#
# @example
#   # bad
#   class Configuration
#     class Error < StandardError; end
#
#     def call
#     end
#   end
#
#   # good
#   class Configuration
#     Error = Class.new(StandardError)
#
#     def call
#     end
#   end
#
class RuboCop::Cop::Callbacksystems::PreferClassNewForEmptyNestedClass < RuboCop::Cop::Callbacksystems::Base
  include RuboCop::Callbacksystems::ProjectIndex::Support
  extend RuboCop::Cop::AutoCorrector

  def on_class(node)
    report EmptyNestedClass.new \
      node,
      RuboCop::Callbacksystems::Source::Comments.for(processed_source),
      assignment_safe: assignment_safe?(node)
  end

  private
    def assignment_safe?(node)
      if node.identifier.namespace.nil? && project_index_reliable?
        declaration = resolve_constant_in_index(node.identifier)

        declaration.is_a?(Rubydex::Class) && DeclarationHistory.new(
          declaration,
          node,
          file: processed_source.file_path
        ).new_at_node?
      else
        false
      end
    end

    # A class declaration can become an assignment only when this node creates the constant. Later declarations in the
    # same file still see that class, while an earlier or externally ordered definition could be overwritten.
    class DeclarationHistory
      def initialize(declaration, node, file:)
        @declaration = declaration
        @node = node
        @file = file
      end

      def new_at_node?
        current_definition && owners_known? && definitions.all? do |definition|
          definition.equal?(current_definition) || later_in_current_file?(definition)
        end
      end

      private
        attr_reader :declaration, :node, :file

        def current_definition
          @current_definition ||= definitions.find do |definition|
            definition.is_a?(Rubydex::ClassDefinition) && same_location?(definition.location, node.source_range)
          end
        end

        def definitions
          @definitions ||= declaration.definitions.to_a
        end

        def same_location?(location, range)
          same_file?(location) && RuboCop::Callbacksystems::ProjectIndex::Location.for_rubydex(location) ==
            RuboCop::Callbacksystems::ProjectIndex::Location.for_ast(range, uri: location.uri)
        end

        def same_file?(location)
          File.identical?(location.to_file_path, file)
        rescue SystemCallError, Rubydex::Location::NotFileUriError
          false
        end

        # A definition beneath a placeholder namespace can be real, but Rubydex cannot prove what an autoloader may
        # already have installed there. Every owner up to Object therefore needs a declaration of its own.
        def owners_known?
          owner_chain_known_from?(declaration.owner)
        end

        def owner_chain_known_from?(owner)
          owner.name == "Object" || (owner.definitions.any? && owner_chain_known_from?(owner.owner))
        end

        def later_in_current_file?(definition)
          same_file?(definition.location) && after_current_definition?(definition.location)
        end

        def after_current_definition?(location)
          ([ location.start_line, location.start_column ] <=> current_position).positive?
        end

        def current_position
          @current_position ||= current_definition.location.then { [ it.start_line, it.start_column ] }
        end
    end

    class EmptyNestedClass
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Declare `%<name>s` as `Class.new` instead of a class definition with no body."

      def initialize(node, source_comments, assignment_safe:)
        @node = node
        @source_comments = source_comments
        @assignment_safe = assignment_safe
      end

      def offense
        if node.body.nil? && nested?
          RuboCop::Callbacksystems::Offense.new(node, message, correcting: correctable?) { correct(it) }
        end
      end

      private
        attr_reader :node, :source_comments, :assignment_safe

        def nested?
          enclosing_class_or_module_of(node).present?
        end

        def message
          format(MESSAGE, name: class_name_of(node))
        end

        def correctable?
          assignment_safe && expression_result.discarded? && superclass_without_heredoc? &&
            comments.none? { tooling_comment?(it) }
        end

        def expression_result
          @expression_result ||= RuboCop::Callbacksystems::Execution::DiscardedExpression.new(node)
        end

        def superclass_without_heredoc?
          node.parent_class.nil? || !carries_heredoc?(node.parent_class)
        end

        def comments
          @comments ||= [ *source_comments.within(node), closing_comment ]
            .compact.uniq.sort_by { it.source_range.begin_pos }
        end

        def closing_comment
          @closing_comment ||= source_comments.trailing_comment_on(node.last_line)&.then do |comment|
            comment if directly_trails_definition?(comment)
          end
        end

        def directly_trails_definition?(comment)
          node.source_range.with(begin_pos: node.source_range.end_pos, end_pos: comment.source_range.begin_pos)
            .source.match?(/\A[ \t]*;?[ \t]*\z/)
        end

        def correct(corrector)
          corrector.replace(correction_range, corrected_source)
        end

        def correction_range
          closing_comment ? node.source_range.join(closing_comment.source_range) : node.source_range
        end

        def corrected_source
          CommentedDeclaration.new(declaration, movable_comments, indentation:).source
        end

        def declaration
          "#{class_name_of(node)} = Class.new#{inherited_class}"
        end

        def inherited_class
          "(#{node.parent_class.source})" if node.parent_class
        end

        def movable_comments
          comments.reject { superclass_contains?(it) }
        end

        def superclass_contains?(comment)
          node.parent_class&.source_range&.contains?(comment.source_range)
        end

        def indentation
          preceding = node.source_range.source_line[0...node.source_range.column]

          preceding.strip.empty? ? preceding : " " * node.source_range.column
        end

        # Comments from the definition keep their order around the declaration, with one former trailing comment still
        # trailing code and every other comment standing on its own line.
        class CommentedDeclaration
          include RuboCop::Callbacksystems::Helpers

          def initialize(declaration, comments, indentation:)
            @declaration = declaration
            @comments = comments
            @indentation = indentation
          end

          def source
            [ *before, declaration_with_comment, *after ].join("\n#{indentation}")
          end

          private
            attr_reader :declaration, :comments, :indentation

            def before
              comments.take(anchor_position).map(&:text)
            end

            def anchor_position
              @anchor_position ||= comments.index { !own_line_comment?(it) } || comments.size
            end

            def declaration_with_comment
              [ declaration, anchor&.text ].compact.join(" ")
            end

            def anchor
              comments[anchor_position] unless anchor_position == comments.size
            end

            def after
              comments.drop(anchor_position + anchor_count).map(&:text)
            end

            def anchor_count
              anchor ? 1 : 0
            end
        end
    end
end
