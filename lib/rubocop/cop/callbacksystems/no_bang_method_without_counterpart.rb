# Prohibits bang methods (ending with `!`) unless a non-bang counterpart exists.
# The `!` suffix should only be used when there's a "safer" version without the bang.
#
# @example
#   # bad - no non-bang counterpart
#   def process!
#     # ...
#   end
#
#   # good - has non-bang counterpart
#   def save
#     # safe version
#   end
#
#   def save!
#     save || raise(RecordNotSaved)
#   end
#
#   # good - no bang needed
#   def process
#     # ...
#   end
#
class RuboCop::Cop::Callbacksystems::NoBangMethodWithoutCounterpart < RuboCop::Cop::Base
  MESSAGE = "Method `%<method>s` has no non-bang counterpart. Only use `!` when a version without `!` exists."

  def on_class(node)
    return unless node.body

    methods = collect_method_names(node.body)
    methods.select { |name| name.to_s.end_with?("!") }.each do |bang_method|
      next if methods.include?(bang_method.to_s.chomp("!").to_sym)

      find_method_node(bang_method, node.body)&.then { |found| add_offense(found, message: format(MESSAGE, method: bang_method)) }
    end
  end

  alias on_module on_class

  private
    def collect_method_names(target_node, names = Set.new)
      return names unless target_node

      names.tap do
        case target_node.type
        when :def, :defs
          names << target_node.method_name
        when :begin, :kwbegin
          target_node.children.each { |child| collect_method_names(child, names) }
        when :sclass
          collect_method_names(target_node.body, names) if target_node.body
        end
      end
    end

    def find_method_node(method_name, target_node)
      return unless target_node

      case target_node.type
      when :def, :defs
        target_node if target_node.method_name == method_name
      when :begin, :kwbegin
        target_node.children.lazy.filter_map { |child| find_method_node(method_name, child) }.first
      when :sclass
        find_method_node(method_name, target_node.body)
      end
    end
end
