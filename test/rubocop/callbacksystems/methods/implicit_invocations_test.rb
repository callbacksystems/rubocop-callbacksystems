require "test_helper"

class RuboCop::Callbacksystems::Methods::ImplicitInvocationsTest < ActiveSupport::TestCase
  test "runtime methods include the callback Ruby invokes when creating a subclass" do
    invocations = []
    parent_class = Class.new
    parent_class.define_singleton_method(:inherited) { |_child| invocations << :inherited }

    Class.new(parent_class)

    assert_equal [ :inherited ], invocations
    assert_includes RuboCop::Callbacksystems::Methods::ImplicitInvocations::RUNTIME_METHODS, invocations.first
    assert_includes RuboCop::Callbacksystems::Methods::ImplicitInvocations::METHOD_NAMES, invocations.first
  end

  test "protocol methods include the conversion Ruby invokes for a hash pattern" do
    invocations = []
    value = Object.new
    value.define_singleton_method(:deconstruct_keys) do |_keys|
      invocations << :deconstruct_keys
      { title: "example" }
    end

    value => { title: "example" }

    assert_equal [ :deconstruct_keys ], invocations
    assert_includes RuboCop::Callbacksystems::Methods::ImplicitInvocations::PROTOCOL_METHODS, invocations.first
    assert_includes RuboCop::Callbacksystems::Methods::ImplicitInvocations::METHOD_NAMES, invocations.first
  end

  test "method names leave an ordinary application method outside implicit invocations" do
    assert_not_includes RuboCop::Callbacksystems::Methods::ImplicitInvocations::METHOD_NAMES, :calculate_invoice_total
  end
end
