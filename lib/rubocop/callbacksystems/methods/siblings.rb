# Direct method definitions indexed within a class or module and its instance/singleton sides.
class RuboCop::Callbacksystems::Methods::Siblings
  include RuboCop::Callbacksystems::Helpers

  def initialize
    @by_container = {}.compare_by_identity
  end

  def named(name, beside:)
    domain = RuboCop::Callbacksystems::Methods::Domain.new(beside)
    definitions_in(domain.container).fetch([ domain.identity, name ]) { [] }
  end

  private
    attr_reader :by_container

    def definitions_in(container)
      return {} if container.nil?

      by_container[container] ||= direct_method_nodes_in(container.body).group_by do |method_node|
        [ RuboCop::Callbacksystems::Methods::Domain.new(method_node).identity, method_node.method_name ]
      end
    end
end
