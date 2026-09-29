module RuboCop::Callbacksystems::Helpers::Names
  def literal_name_of(node)
    node.type?(:sym, :str) ? node.value.to_s : node.source
  end

  def declared_name_of(statement)
    case statement.type
    when :casgn, :lvasgn then statement.name
    when :class, :module then statement.identifier.short_name
    end
  end

  def name_arguments_of(node)
    node.arguments.select { it.type?(:sym, :str) }
  end

  def class_name_of(node)
    node.class_type? ? node.identifier.source : node.name.to_s
  end

  def name_without_sigil(name)
    name.to_s.sub(/\A(?:@@|@|\$)/, "")
  end

  def constant_name_of(node)
    if node
      ConstantName.new(node).to_s
    end
  end

  private
    class ConstantName
      def initialize(node)
        @current = node
        @names = []
      end

      def to_s
        traverse
        name if complete?
      end

      private
        attr_reader :current, :names

        def traverse
          while current&.const_type?
            names << current.short_name
            @current = current.namespace
          end
        end

        def complete?
          current.nil? || current.cbase_type?
        end

        def name
          "#{prefix}#{names.reverse.join("::")}"
        end

        def prefix
          "::" if current && names.any?
        end
    end
end
