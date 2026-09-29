module RuboCop::Callbacksystems::ProjectIndex::Loader
  def build_index(paths)
    super.tap do |project_index|
      if project_index
        RuboCop::Callbacksystems::ProjectIndex::Coverage.register(project_index, paths:)
      end
    end
  end
end
