# The method names one class-body statement defines. A missing result means the statement does define methods, but their
# complete names cannot be proven without executing the file.
class RuboCop::Callbacksystems::Methods::StatementDefinitions
  include RuboCop::Callbacksystems::Helpers

  RUBY_ACCESSOR_MACROS = %i[ attr_reader attr_writer attr_accessor ]

  def initialize(statement)
    @statement = statement
  end

  def names
    @names ||= explicit_definition_names || macro_definition_names
  end

  private
    attr_reader :statement

    def explicit_definition_names
      Set[statement.method_name] if statement.type?(:def, :defs)
    end

    def macro_definition_names
      if delegate_macro?(macro)
        RuboCop::Callbacksystems::Methods::DelegateMacro.new(macro).defined_method_names&.to_set
      elsif scope_macro?
        scope_names
      elsif ruby_accessor_macro?
        accessor_names
      elsif attribute_macro?(macro) || association_macro?(macro)
        nil
      else
        Set.new
      end
    end

    def macro
      @macro ||= call_of(statement)
    end

    def scope_macro?
      bare_send?(macro) && macro.method?(:scope)
    end

    def scope_names
      name = macro.first_argument

      name&.type?(:sym, :str) ? Set[name.value.to_sym] : nil
    end

    def ruby_accessor_macro?
      bare_send?(macro) && RUBY_ACCESSOR_MACROS.include?(macro.method_name)
    end

    def accessor_names
      return if macro.arguments.any? { !it.type?(:sym, :str) }

      names = name_arguments_of(macro).to_set { it.value.to_sym }

      if macro.method?(:attr_reader)
        names
      elsif macro.method?(:attr_writer)
        names.to_set { :"#{it}=" }
      else
        names | names.to_set { :"#{it}=" }
      end
    end
end
