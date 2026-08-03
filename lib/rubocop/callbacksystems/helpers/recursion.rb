module RuboCop::Callbacksystems::Helpers::Recursion
  # A different value at every step cannot be the shared state of a class, so the
  # cops that would advise making it a field leave it alone.
  def recursion_subject_names_in(node)
    (derived_subject_names_in(node) + shifted_subject_names_in(node)).to_set
  end

  # `walk(node.child, node)`: passed directly and as the receiver of a value
  # derived from it, in one call.
  def derived_subject_names_in(node)
    node.each_node(:send).flat_map { recursion_subjects_in(it) }
  end

  def recursion_subjects_in(call)
    receiver_names = derived_receiver_names_in(call)
    direct_argument_names_in(call).select { receiver_names.include?(it) }
  end

  def derived_receiver_names_in(call)
    call.arguments.filter_map { local_variable_name_of(it.receiver) if it.send_type? }.to_set
  end

  def local_variable_name_of(argument)
    argument.children.first.to_s if argument&.lvar_type?
  end

  def direct_argument_names_in(call)
    call.arguments.filter_map { local_variable_name_of(it) }
  end

  # `walk(child, node)` inside `def walk(node, parent)`: the subject moves down
  # the parameter list.
  def shifted_subject_names_in(node)
    node.each_node(:def, :defs).flat_map { RuboCop::Callbacksystems::MethodRecursion.new(it).shifted_names }
  end
end
