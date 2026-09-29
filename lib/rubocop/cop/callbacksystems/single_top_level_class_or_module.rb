# Forbids a second class or module at the top level of a file. Zeitwerk expects
# the path of a file to name the constant it defines, so a second definition is
# one nothing autoloads, and a reader looking for it by name never finds the
# file it sits in.
#
# A class extending one written above it in the same file is left alone. Moving it
# out would need a `require` back, so the two sitting together is a hierarchy
# rather than the sprawl this looks for.
#
# @example
#   # bad - multiple top-level classes
#   class User
#   end
#
#   class Admin
#   end
#
#   # bad - multiple top-level modules
#   module Authentication
#   end
#
#   module Authorization
#   end
#
#   # bad - mixed top-level class and module
#   class User
#   end
#
#   module UserHelpers
#   end
#
#   # good - single top-level class
#   class User
#   end
#
#   # good - single top-level module
#   module Authentication
#   end
#
#   # good - nested classes/modules inside one top-level
#   class User
#     class Profile
#     end
#
#     module Validations
#     end
#   end
#
#   # good - a hierarchy the file declares together
#   class BaseTest < ActiveSupport::TestCase
#   end
#
#   class VariantTest < BaseTest
#   end
#
class RuboCop::Cop::Callbacksystems::SingleTopLevelClassOrModule < RuboCop::Cop::Callbacksystems::Base
  def on_new_investigation
    report_each TopLevelDefinitions.new(processed_source.ast)
  end

  private
    class TopLevelDefinitions
      include RuboCop::Callbacksystems::Helpers

      MESSAGE = "Only one top-level class or module is allowed per file."
      TRANSPARENT_NODES = %i[
        begin kwbegin if case case_match when in_pattern rescue resbody ensure
      ]

      def initialize(ast)
        @ast = ast
      end

      def each_offense
        standalone.each { yield RuboCop::Callbacksystems::Offense.new(it, MESSAGE) }
      end

      private
        attr_reader :ast

        def standalone
          definitions.drop(1).reject { it.extends?(definitions) }.map(&:node)
        end

        def definitions
          @definitions ||= definitions_in(ast)
        end

        def definitions_in(node)
          Enumerator.new do |definitions|
            pending = [ node ].compact
            until pending.empty?
              current = pending.pop
              definition = Definition.new(current)
              if definition.declared?
                definitions << definition
              elsif current.type?(*TRANSPARENT_NODES)
                pending.concat(current.child_nodes.reverse)
              end
            end
          end.to_a
        end

        class Definition
          include RuboCop::Callbacksystems::Helpers

          attr_reader :node

          def initialize(node)
            @node = node
          end

          def declared?
            node.type?(:class, :module) || builder_declaration?
          end

          def extends?(definitions)
            parent_class.then { |parent| parent && definitions.any? { it.name == parent.source } }
          end

          def name
            node.type?(:class, :module) ? node.identifier.source : assigned_constant_name
          end

          private
            def builder_declaration?
              if node.casgn_type?
                builder_assignment.builds_class? || builder_assignment.builds_module?
              else
                false
              end
            end

            def builder_assignment
              @builder_assignment ||= RuboCop::Callbacksystems::ClassStructure::BuilderAssignment.new(node)
            end

            def parent_class
              if node.class_type?
                node.parent_class
              elsif node.casgn_type? && class_new_builder?
                builder_call.first_argument
              end
            end

            def class_new_builder?
              builder_call&.method?(:new) && core_constant?(builder_call.receiver) &&
                builder_call.receiver.short_name == :Class
            end

            def builder_call
              @builder_call ||= call_of(node.expression)
            end

            def assigned_constant_name
              node.source_range.with(end_pos: node.loc.operator.begin_pos).source.rstrip
            end
        end
    end
end
