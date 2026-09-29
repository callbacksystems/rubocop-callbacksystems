# One derived reading per consumer, replaced whenever its project graph or in-memory revision changes.
module RuboCop::Callbacksystems::ProjectIndex::Cache
  def for(project_index)
    generation = RuboCop::Callbacksystems::ProjectIndex::Freshness.generation(project_index)
    cached_index_reading.then do |index, cached_generation, reading|
      if index.equal?(project_index) && cached_generation == generation
        reading
      else
        new(project_index).tap { self.cached_index_reading = [ project_index, generation, it ] }
      end
    end
  end

  private
    attr_accessor :cached_index_reading
end
