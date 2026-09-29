module RuboCop::Callbacksystems::Helpers::Recursion
  # A recursion subject is a name passed both bare and as the receiver of a derived value: `walk(node.child, node)`.
  def recursion_subject_names_in(node)
    if node
      calls = node.each_node(:send, :csend)
      calls = [ node ].chain(calls) if node.call_type?
      calls.flat_map { recursion_subjects_in(it) }.to_set
    else
      Set.new
    end
  end

  def recursion_subjects_in(call)
    receiver_names = derived_receiver_names_in(call)
    direct_argument_names_in(call).select { receiver_names.include?(it) }
  end

  def derived_receiver_names_in(call)
    call.arguments.filter_map { local_variable_name_of(it.receiver) if it.call_type? }.to_set
  end

  def local_variable_name_of(argument)
    argument.children.first.to_s if argument&.lvar_type?
  end

  def direct_argument_names_in(call)
    call.arguments.filter_map { local_variable_name_of(it) }
  end
end
