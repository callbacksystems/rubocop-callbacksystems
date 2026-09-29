module RuboCop::Callbacksystems::Helpers::NodeTypes
  BLOCK_NODE_TYPES = %i[ block numblock itblock ]

  def declaration_macro?(node)
    attribute_macro?(node) || delegate_macro?(node)
  end

  def attribute_macro?(node)
    bare_send?(node) && ATTRIBUTE_MACROS.include?(node.method_name)
  end

  def bare_send?(node)
    node&.send_type? && node.receiver.nil?
  end

  def delegate_macro?(node)
    bare_send?(node) && DELEGATE_MACROS.include?(node.method_name)
  end

  def mixin_macro?(node)
    bare_send?(node) && MIXIN_MACROS.include?(node.method_name)
  end

  def association_macro?(node)
    bare_send?(node) && ASSOCIATION_MACROS.include?(node.method_name)
  end

  def call_on_self?(node)
    node&.call_type? && (node.receiver.nil? || node.receiver.self_type?)
  end

  def singleton_section?(node)
    node&.sclass_type? && node.identifier.self_type?
  end

  def structural_self?(node)
    (node.parent&.sclass_type? && node.parent.identifier.equal?(node)) ||
      (node.parent&.defs_type? && node.parent.receiver.equal?(node))
  end

  def definition_identifier?(node)
    node.parent&.type?(:class, :module) && node.parent.identifier.equal?(node)
  end

  def reads_of(variable_name, within:)
    nodes_in(within, :lvar, :ivar).select { reads_variable?(it, variable_name) }
  end

  def nodes_in(tree, *types)
    tree ? tree.each_node(*types).to_a : []
  end

  def reads_variable?(node, variable_name)
    node&.type?(:lvar, :ivar) && node.name == variable_name
  end

  def definition_nodes_in(tree)
    nodes_in(tree, :class, :module, :sclass)
  end

  def reads_as_string?(node)
    node && reads_as?(node, literals: STRING_LITERAL_TYPES, methods: STRING_RESULT_METHODS)
  end

  def reads_as?(node, literals:, methods:)
    literals.include?(node.type) || (node.call_type? && methods.include?(node.method_name))
  end

  def reads_as_array?(node)
    node&.array_type? || array_construction?(node)
  end

  def call_of(node)
    any_block_type?(node) ? node.send_node : node
  end

  def any_block_type?(node)
    node && BLOCK_NODE_TYPES.include?(node.type)
  end

  def core_constant?(node)
    node&.const_type? && (node.namespace.nil? || node.namespace.cbase_type?)
  end

  def empty_collection_literal?(node)
    node&.type?(:array, :hash) && node.children.empty?
  end

  def loop_block?(node)
    node.method?(:loop)
  end

  def returned_expression_of(node)
    node.return_type? ? node.children.first : node
  end

  def hash_pairs_of(send_node)
    send_node.arguments.select(&:hash_type?).flat_map(&:pairs)
  end

  def top_level_definitions_in(node)
    TopLevelDefinitions.new(node).to_a
  end

  private
    ARRAY_CONSTRUCTION_METHODS = %i[ new [] ]
    STRING_LITERAL_TYPES = %i[ dstr str xstr ]
    STRING_RESULT_METHODS = %i[
      to_s to_str to_json to_param to_query inspect join strip lstrip rstrip squish chomp chop
      gsub sub tr delete_prefix delete_suffix upcase downcase capitalize swapcase titleize humanize
      parameterize dasherize underscore camelize classify tableize demodulize truncate name
    ]

    ATTRIBUTE_MACROS =
      %i[ attr_reader attr_writer attr_accessor attribute class_attribute has_secure_password has_secure_token ]
    DELEGATE_MACROS = %i[ delegate delegate_missing_to ]
    MIXIN_MACROS = %i[ include extend prepend ]
    ASSOCIATION_MACROS = %i[
      belongs_to has_many has_one has_and_belongs_to_many delegated_type
      has_one_attached has_many_attached has_rich_text accepts_nested_attributes_for
    ]

    def array_construction?(node)
      node&.send_type? && core_constant?(node.receiver) && node.receiver.short_name == :Array &&
        ARRAY_CONSTRUCTION_METHODS.include?(node.method_name)
    end

    # Class and module definitions opened by a file, with only top-level begin nodes transparent.
    class TopLevelDefinitions
      include Enumerable

      def initialize(node)
        @node = node
      end

      def each
        if block_given?
          pending = [ node ].compact
          until pending.empty?
            current = pending.pop
            case current.type
            when :class, :module then yield current
            when :begin then pending.concat(current.each_child_node.to_a.reverse)
            end
          end
        else
          to_enum(__method__)
        end
      end

      private
        attr_reader :node
    end
end
