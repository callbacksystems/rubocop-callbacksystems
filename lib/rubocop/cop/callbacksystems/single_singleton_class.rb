# A class declares its class-level methods in a single `class << self` section.
# Splitting them across several blocks scatters the class API and hides which
# part of it is private.
#
# @example
#   # bad - two singleton sections
#   class Configuration
#     class << self
#       def create_from(file)
#       end
#     end
#
#     def initialize(raw_config)
#     end
#
#     class << self
#       private
#         def load_config_files(file)
#         end
#     end
#   end
#
#   # good - one singleton section
#   class Configuration
#     class << self
#       def create_from(file)
#       end
#
#       private
#         def load_config_files(file)
#         end
#     end
#
#     def initialize(raw_config)
#     end
#   end
#
class RuboCop::Cop::Callbacksystems::SingleSingletonClass < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Merge this `class << self` into the one declared above; a class has a single singleton section."

  def on_class(node)
    singleton_sections_in(node).drop(1).each { add_offense(it, message: MESSAGE) }
  end

  private
    def singleton_sections_in(node)
      statements_in(node.body).select { singleton_section?(it) }
    end
end
