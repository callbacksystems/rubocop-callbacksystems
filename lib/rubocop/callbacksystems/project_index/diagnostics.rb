class RuboCop::Callbacksystems::ProjectIndex::Diagnostics
  extend RuboCop::Callbacksystems::ProjectIndex::Cache

  def initialize(project_index)
    @by_rule_name = {}
    @by_rule_name_and_uri = {}
    project_index.diagnostics.each { index(it) }
  end

  def any_named?(*rule_names)
    diagnostics_named(rule_names).any?
  end

  def within_definitions?(definitions, named:)
    definitions.any? do |definition|
      diagnostics_named_in(definition.location.uri, named).any? do |diagnostic|
        LocationContainment.new(definition.location, diagnostic.location).contained?
      end
    end
  end

  private
    attr_reader :by_rule_name, :by_rule_name_and_uri

    def index(diagnostic)
      rule_name = diagnostic.rule.rule_name
      (by_rule_name[rule_name] ||= []) << diagnostic
      (by_rule_name_and_uri[[ rule_name, diagnostic.location.uri ]] ||= []) << diagnostic
    end

    def diagnostics_named(rule_names)
      rule_names.flat_map { by_rule_name.fetch(it) { [] } }
    end

    def diagnostics_named_in(uri, rule_names)
      rule_names.flat_map { by_rule_name_and_uri.fetch([ it, uri ]) { [] } }
    end

    class LocationContainment
      def initialize(outer, inner)
        @outer = outer
        @inner = inner
      end

      def contained?
        outer.uri == inner.uri && starts_before? && ends_after?
      end

      private
        attr_reader :outer, :inner

        def starts_before?
          ([ outer.start_line, outer.start_column ] <=> [ inner.start_line, inner.start_column ]) <= 0
        end

        def ends_after?
          ([ outer.end_line, outer.end_column ] <=> [ inner.end_line, inner.end_column ]) >= 0
        end
    end
end
