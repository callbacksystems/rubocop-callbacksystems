# Calls on self indexed by their enclosing class and method domain, so several definitions can ask who calls them
# without each walking the whole class again.
class RuboCop::Callbacksystems::Methods::Calls
  include RuboCop::Callbacksystems::Helpers

  def initialize(ast)
    @ast = ast
  end

  def named(name, from:)
    domain = RuboCop::Callbacksystems::Methods::Domain.new(from)
    calls_in(domain.container, identity: domain.identity).fetch(name) { [] }
  end

  private
    attr_reader :ast

    def calls_in(container, identity:)
      calls_by_container[container]&.fetch(identity, {}) || {}
    end

    def calls_by_container
      @calls_by_container ||= {}.compare_by_identity.tap do |index|
        nodes_in(ast, :send, :csend).each { add(it, to: index) if call_on_self?(it) }
      end
    end

    def add(call, to:)
      domain = domain_of_call(call)
      scopes = to[domain.container] ||= {}
      calls = scopes[domain.identity] ||= {}
      (calls[call.method_name] ||= []) << call
    end

    def domain_of_call(call)
      RuboCop::Callbacksystems::Methods::Domain.new(call)
    end
end
