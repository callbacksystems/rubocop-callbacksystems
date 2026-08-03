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
  extend RuboCop::Cop::AutoCorrector

  MESSAGE = "Declare `%<name>s` as `Class.new` instead of a class definition with no body."

  def on_class(node)
    definition = EmptyNestedClass.new(node, processed_source.comments)
    add_offense(node, message: definition.offense_message) { definition.rewrite(it) } if definition.offense?
  end

  private
    class EmptyNestedClass
      include RuboCop::Callbacksystems::Helpers

      def initialize(node, comments)
        @node = node
        @comments = comments
      end

      def offense?
        empty_body? && nested?
      end

      def offense_message
        format(MESSAGE, name: name)
      end

      def rewrite(corrector)
        RuboCop::Callbacksystems::LiftedComments.new(node, comments_in(node.source_range, comments)).lift(corrector)
        corrector.replace(node, "#{name} = Class.new#{inherited_class}")
      end

      private
        attr_reader :node, :comments

        def empty_body?
          node.body.nil?
        end

        def nested?
          enclosing_class_or_module_of(node).present?
        end

        def name
          node.identifier.source
        end

        def inherited_class
          "(#{node.parent_class.source})" if node.parent_class
        end
    end
end
