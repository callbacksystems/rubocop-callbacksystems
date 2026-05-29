module RuboCop::Callbacksystems::Helpers::Recursion
  # A name passed both directly and as the receiver of a derived value in the
  # same call (`walk(node.child, node)`) is a recursion subject: it mutates
  # every step, so it cannot be the shared state of a class.
  def recursion_subject_names_in(node)
    node.each_node(:send).flat_map { recursion_subjects_in(it) }.to_set
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
end
