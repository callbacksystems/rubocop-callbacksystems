# Whether every visible use of a nested class and every instance it constructs stays within the file.
class RuboCop::Callbacksystems::ProjectIndex::NestedClassConfinement
  include RuboCop::Callbacksystems::Helpers

  CONSTRUCTION_METHODS = %i[ allocate new ]
  MIXIN_METHODS = %i[ extend include prepend ]
  CLASS_BODY_PRIMITIVES = %i[
    alias_method attr attr_accessor attr_reader attr_writer deprecate_constant module_function
    private private_class_method private_constant protected public public_class_method public_constant
    remove_method ruby2_keywords undef_method
  ]
  VALUE_EXPOSURE_METHODS = %i[
    __send__ binding clone dup enum_for freeze instance_eval instance_exec itself method public_method public_send
    send singleton_class singleton_method tap then to_enum yield_self
  ]
  HANDOFF_TYPES = %i[
    array hash pair splat kwsplat block_pass yield return super break next def defs
    and or case when rescue resbody ensure for match_pattern match_pattern_p irange erange
    lvasgn ivasgn cvasgn gvasgn casgn masgn or_asgn and_asgn op_asgn
  ].to_set.merge(RuboCop::Callbacksystems::Helpers::NodeTypes::BLOCK_NODE_TYPES)

  def initialize(nested_class, declaration:, project_index:)
    @nested_class = nested_class
    @declaration = declaration
    @project_index = project_index
  end

  def confined?
    return @confined if defined?(@confined)

    @confined = definition_confined? && values_confined?
  end

  private
    attr_reader :nested_class, :declaration, :project_index

    def definition_confined?
      nested_class.parent_class.nil? && !mixin_used? && !singleton_callback_defined? &&
        references_in_definition_file? && all_references_located? && reference_nodes.all? { safe_reference?(it) }
    end

    def mixin_used?
      sends.any? do |send_node|
        call_on_self?(send_node) && MIXIN_METHODS.include?(send_node.method_name)
      end
    end

    def sends
      @sends ||= nodes_in(nested_class.body, :send, :csend)
    end

    def singleton_callback_defined?
      direct_method_nodes.any? do |definition|
        RuboCop::Callbacksystems::Methods::ImplicitInvocations::RUNTIME_METHODS.include?(definition.method_name) &&
          singleton_definition?(definition)
      end
    end

    def direct_method_nodes
      @direct_method_nodes ||= direct_method_nodes_in(nested_class.body)
    end

    def singleton_definition?(definition)
      RuboCop::Callbacksystems::Methods::Domain.new(definition).identity.then do |identity|
        identity.present? && identity.all? { it == :self }
      end
    end

    def references_in_definition_file?
      definition_uris.one? && references.all? { definition_uris.include?(it.location.uri) }
    end

    def definition_uris
      @definition_uris ||= declaration.definitions.to_set { it.location.uri }
    end

    def references
      @references ||= declaration.references.to_a
    end

    def all_references_located?
      reference_nodes.size == references.size
    end

    def reference_nodes
      @reference_nodes ||= references.filter_map { const_node_at(it.location) }
    end

    def const_node_at(location)
      SourceConstants.for(source_root, uri: location.uri).at(location)
    end

    def source_root
      @source_root ||= nested_class.then do |node|
        node = node.parent while node.parent
        node
      end
    end

    def safe_reference?(node)
      namespace_prefix?(node) || locally_consumed_construction?(node)
    end

    def namespace_prefix?(node)
      node.parent.const_type? && node.parent.namespace.equal?(node)
    end

    def locally_consumed_construction?(node)
      node.parent.call_type? && node.parent.receiver.equal?(node) && construction?(node.parent) &&
        !handed_off?(node.parent)
    end

    def construction?(send_node)
      CONSTRUCTION_METHODS.include?(send_node.method_name)
    end

    def handed_off?(candidate)
      CarriedValue.new(candidate).outermost.then do |value|
        value.parent&.type?(*HANDOFF_TYPES) || passed_as_argument?(value)
      end
    end

    def passed_as_argument?(value)
      value.parent&.call_type? && !value.parent.receiver.equal?(value)
    end

    def values_confined?
      !class_escapes? && !instance_escapes? && method_dispatch_confined? &&
        implicit_constructions.none? { implicit_construction_escapes?(it) }
    end

    def class_escapes?
      class_values.any? { handed_off?(it) } || opaque_class_body_call?
    end

    def class_values
      explicit_class_values + implicit_class_values
    end

    def explicit_class_values
      self_nodes.select do |self_node|
        !structural_self?(self_node) && possible_class_side?(self_node)
      end
    end

    def self_nodes
      @self_nodes ||= nodes_in(nested_class.body, :self)
    end

    def possible_class_side?(node)
      RuboCop::Callbacksystems::Methods::Domain.new(node).then do |domain|
        if domain.container.equal?(nested_class)
          domain.singleton?
        else
          opaque_block_in_nested_class?(domain.container)
        end
      end
    end

    def opaque_block_in_nested_class?(container)
      any_block_type?(container) && enclosing_class_or_module_of(container).equal?(nested_class)
    end

    def implicit_class_values
      sends.select do |send_node|
        VALUE_EXPOSURE_METHODS.include?(send_node.method_name) && call_on_self?(send_node) &&
          possible_class_side?(send_node)
      end
    end

    def opaque_class_body_call?
      sends.any? do |send_node|
        direct_class_body_call?(send_node) && call_on_self?(send_node) &&
          !trusted_class_body_call?(send_node)
      end
    end

    def direct_class_body_call?(send_node)
      enclosing_method_of(send_node).nil? && enclosing_class_or_module_of(send_node).equal?(nested_class)
    end

    def trusted_class_body_call?(send_node)
      CLASS_BODY_PRIMITIVES.include?(send_node.method_name) && !class_method_redefined?(send_node.method_name)
    end

    def class_method_redefined?(method_name)
      project_index["Class"].find_member("#{method_name}()")&.definitions&.any? || false
    rescue
      true
    end

    def instance_escapes?
      instance_values.any? { handed_off?(it) }
    end

    def instance_values
      explicit_instance_values + implicit_instance_values
    end

    def explicit_instance_values
      self_nodes.select { possible_instance_side?(it) }
    end

    def possible_instance_side?(node)
      RuboCop::Callbacksystems::Methods::Domain.new(node).then do |domain|
        (domain.container.equal?(nested_class) && !domain.singleton?) ||
          opaque_block_in_nested_class?(domain.container)
      end
    end

    def implicit_instance_values
      sends.select do |send_node|
        VALUE_EXPOSURE_METHODS.include?(send_node.method_name) && call_on_self?(send_node) &&
          possible_instance_side?(send_node)
      end
    end

    def method_dispatch_confined?
      RuboCop::Callbacksystems::ProjectIndex::NestedClassMethodDispatch.new(nested_class, declaration:).confined?
    end

    def implicit_constructions
      sends.select do |send_node|
        construction?(send_node) && call_on_self?(send_node) && possible_class_side?(send_node)
      end
    end

    def implicit_construction_escapes?(construction)
      opaque_block_in_nested_class?(RuboCop::Callbacksystems::Methods::Domain.new(construction).container) ||
        handed_off?(construction)
    end

    class SourceConstants
      class << self
        def for(source_root, uri:)
          context = Context.new(source_root, uri)

          cached.then do |cached_context, constants|
            if cached_context&.same_source?(context)
              constants
            else
              new(context).tap { self.cached = [ context, it ] }
            end
          end
        end

        private
          attr_accessor :cached
      end

      def initialize(context)
        @by_location = context.source_root.each_node(:const).group_by do |node|
          RuboCop::Callbacksystems::ProjectIndex::Location.for_ast(node.loc.name, uri: context.uri)
        end
      end

      def at(location)
        key = RuboCop::Callbacksystems::ProjectIndex::Location.for_rubydex(location)
        by_location.fetch(key) { [] }.then { it.first if it.one? }
      end

      private
        attr_reader :by_location

        class Context < Data.define(:source_root, :uri)
          def same_source?(other)
            source_root.equal?(other.source_root) && uri == other.uri
          end
        end
    end

    class CarriedValue
      def initialize(node)
        @node = node
      end

      def outermost
        node.then do |current|
          current = current.parent while carries_value?(current.parent, child: current)
          current
        end
      end

      private
        attr_reader :node

        def carries_value?(parent, child:)
          case parent&.type
          when :begin, :kwbegin then parent.children.last.equal?(child)
          when :if then parent.children.drop(1).any?(child)
          when :send, :csend then parent.receiver.equal?(child)
          when :class, :module, :sclass then parent.body.equal?(child)
          else false
          end
        end
    end
end
