# A class whose whole body is class-level code should be a module with
# `extend self`. Classes are for making instances.
#
# `Style/StaticClass` covers the plain case, but it abstains as soon as the
# singleton section has a private part, because the `module_function` it
# corrects to stops copying methods to the singleton once `private` switches
# the mode, which breaks every call to them. `extend self` carries the
# visibility over untouched, so that case is reported here instead.
#
# @example
#   # bad - class methods only, with a private helper
#   class Architecture
#     class << self
#       def resolve(reports)
#         normalize(reports)
#       end
#
#       private
#         def normalize(raw)
#           raw.downcase
#         end
#     end
#   end
#
#   # good
#   module Architecture
#     extend self
#
#     def resolve(reports)
#       normalize(reports)
#     end
#
#     private
#       def normalize(raw)
#         raw.downcase
#       end
#   end
#
class RuboCop::Cop::Callbacksystems::PreferModuleForStaticClass < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Prefer a module with `extend self` to a class holding only class methods."

  def on_class(node)
    add_offense(node, message: MESSAGE) if StaticClass.new(node).offense?
  end

  private
    class StaticClass
      include RuboCop::Callbacksystems::Helpers

      def initialize(node)
        @node = node
      end

      def offense?
        convertible? && private_singleton_section?
      end

      private
        attr_reader :node

        def convertible?
          node.parent_class.nil? && only_class_level_statements?
        end

        def only_class_level_statements?
          statements.any? && statements.all? { class_level_statement?(it) }
        end

        def statements
          @statements ||= statements_in(node.body)
        end

        def class_level_statement?(statement)
          statement.type?(:casgn, :defs) || extend_call?(statement) || singleton_section?(statement)
        end

        def extend_call?(statement)
          bare_send?(statement) && statement.method?(:extend)
        end

        # Only the sections the core cop refuses to touch, so the two do not
        # report the same class twice.
        def private_singleton_section?
          statements.select { singleton_section?(it) }.any? { holds_private_section?(it) }
        end

        def holds_private_section?(section)
          private_modifier_in(section.body).present?
        end
    end
end
