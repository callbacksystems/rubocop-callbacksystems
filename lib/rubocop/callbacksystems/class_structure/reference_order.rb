# The order that reads each name before the names it refers to, walked depth first from the seeds it is given. The graph
# maps a name to the names it refers to, and a name the graph does not hold is skipped.
class RuboCop::Callbacksystems::ClassStructure::ReferenceOrder
  include Enumerable

  delegate :each, to: :ordered

  def initialize(seeds, graph)
    @seeds = seeds
    @graph = graph
  end

  private
    attr_reader :seeds, :graph

    def ordered
      @ordered ||= seeds.each_with_object([]) { |name, order| gather(name, order) }
    end

    def gather(name, order)
      stack = [ name ]

      until stack.empty?
        current = stack.pop
        next if visited.include?(current) || graph.exclude?(current)

        visited.add(current)
        order << current
        graph.fetch(current).reverse_each { stack << it if visited.exclude?(it) }
      end
    end

    def visited
      @visited ||= Set.new
    end
end
