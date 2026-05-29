module RuboCop::Callbacksystems::Helpers
  extend self

  def const_added(name)
    super
    helper = const_get(name)
    Wiring.new(self, helper).perform unless helper.is_a?(Class)
  end

  private
    class Wiring
      def initialize(helpers, submodule)
        @helpers = helpers
        @submodule = submodule
      end

      def perform
        if helper_module?(submodule)
          siblings.each { extend_mutually(it) }
          helpers.include(submodule)
        end
      end

      private
        attr_reader :helpers, :submodule

        def helper_module?(const)
          const.is_a?(Module) && !const.is_a?(Class)
        end

        def siblings
          helpers.constants.filter_map do |name|
            candidate = helpers.const_get(name)
            candidate if helper_module?(candidate) && candidate != submodule
          end
        end

        def extend_mutually(other)
          submodule.extend(other) unless submodule.singleton_class < other
          other.extend(submodule) unless other.singleton_class < submodule
        end
    end
end
