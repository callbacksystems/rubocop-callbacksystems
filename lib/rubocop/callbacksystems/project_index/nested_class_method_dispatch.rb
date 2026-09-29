# Whether self-dispatch inside a nested class stays on methods the class itself owns.
class RuboCop::Callbacksystems::ProjectIndex::NestedClassMethodDispatch
  include RuboCop::Callbacksystems::Helpers

  def initialize(nested_class, declaration:)
    @nested_class = nested_class
    @declaration = declaration
  end

  def confined?
    self_calls.all? { owned_method_call?(it) } && !super_dispatch?
  end

  private
    attr_reader :nested_class, :declaration

    def self_calls
      nodes_in(nested_class.body, :send, :csend).select do |send_node|
        call_on_self?(send_node) && enclosing_method_of(send_node) && method_owner_of(send_node)
      end
    end

    def method_owner_of(send_node)
      RuboCop::Callbacksystems::Methods::Domain.new(send_node).then do |domain|
        owner_for(domain.identity) if domain.container.equal?(nested_class)
      end
    end

    def owner_for(identity)
      if identity.empty?
        declaration
      elsif identity.all? { it == :self }
        declaration.singleton_class
      end
    end

    def owned_method_call?(send_node)
      method_owner_of(send_node).then do |owner|
        owner.member("#{send_node.method_name}()").present?
      end
    rescue
      false
    end

    def super_dispatch?
      nodes_in(nested_class.body, :super, :zsuper).any? do |super_node|
        enclosing_class_or_module_of(super_node).equal?(nested_class)
      end
    end
end
