# Represents a fixture method call in test files.
# A fixture call is a method like `users(:john)` or `accounts(:callback)`.
#
# @example
#   fixture_call = RuboCop::Callbacksystems::FixtureCall.new(node)
#   fixture_call.valid?     # => true if node is a fixture call
#   fixture_call.signature  # => "users(:john)"
#
class RuboCop::Callbacksystems::FixtureCall
  def initialize(node)
    @node = node
  end

  attr_reader :node

  def valid?
    node&.send_type? && no_receiver? && single_symbol_argument? && pluralized_method_name?
  end

  def signature
    "#{node.method_name}(:#{node.arguments.first.value})"
  end

  private
    def no_receiver?
      !node.receiver
    end

    def single_symbol_argument?
      node.arguments.size == 1 && node.arguments.first.sym_type?
    end

    def pluralized_method_name?
      name = node.method_name.to_s
      name.singularize.pluralize == name
    end
end
