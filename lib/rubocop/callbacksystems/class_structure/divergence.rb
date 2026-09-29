# The first place a sequence of names departs from the order expected of it, read as the index, the name the order
# expects there and the name found instead.
class RuboCop::Callbacksystems::ClassStructure::Divergence
  def initialize(names, from:)
    @names = names
    @order = from
  end

  def found?
    index.present?
  end

  def index
    @index ||= names.each_index.find { names[it] != order[it] } if comparable?
  end

  def expected
    order[index]
  end

  def actual
    names[index]
  end

  private
    attr_reader :names, :order

    def comparable?
      names.size == order.size && names.tally == order.tally
    end
end
