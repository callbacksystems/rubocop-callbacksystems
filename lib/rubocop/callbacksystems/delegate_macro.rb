class RuboCop::Callbacksystems::DelegateMacro
  include RuboCop::Callbacksystems::Helpers

  def initialize(node)
    @node = node
  end

  def macro?
    bare_send?(node) && node.method?(:delegate) && !options.nil?
  end

  def target
    value_of(:to)&.then { it.value.to_s if it.type?(:sym, :str) }
  end

  def private?
    value_of(:private)&.true_type? || false
  end

  def first_option
    options.pairs.first
  end

  def last_option
    options.pairs.last
  end

  private
    attr_reader :node

    def options
      node.last_argument if node.last_argument&.hash_type?
    end

    def value_of(key)
      options.pairs.find { it.key.sym_type? && it.key.value == key }&.value
    end
end
