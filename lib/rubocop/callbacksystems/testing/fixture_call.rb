class RuboCop::Callbacksystems::Testing::FixtureCall < Data.define(:node)
  include RuboCop::Callbacksystems::Helpers

  def valid?
    bare_send?(node) &&
      node.arguments.size == 1 &&
      node.first_argument.sym_type? &&
      fixture_set?
  end

  def signature
    "#{node.method_name}(#{node.first_argument.source})"
  end

  def identity
    [ node.method_name, node.first_argument.value ]
  end

  private
    delegate :source_buffer, to: "node.source_range", private: true

    # A helper reads like a fixture call, so the project's own fixture sets are what tells the two apart.
    def fixture_set?
      RuboCop::Callbacksystems::Testing::FixtureNames.new(file_path, lifetime: source_buffer).include?(node.method_name)
    end

    def file_path
      source_buffer.name
    end
end
