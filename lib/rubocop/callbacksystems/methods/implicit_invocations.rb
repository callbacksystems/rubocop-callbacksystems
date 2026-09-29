module RuboCop::Callbacksystems::Methods::ImplicitInvocations
  # These hooks supplement the smaller runtime set shipped by RuboCop 1.89.
  RUNTIME_METHODS = %i[
    coerce instance_variables_to_inspect
    inherited included extended prepended
    append_features extend_object prepend_features
    const_missing const_added
    method_added method_removed method_undefined
    singleton_method_added singleton_method_removed singleton_method_undefined
  ].to_set | RuboCop::Cop::Lint::UnusedPrivateMethod::IMPLICITLY_INVOKED_METHODS
  PROTOCOL_METHODS = %i[
    initialize to_hash to_h to_str to_s to_ary to_a to_proc to_int to_i to_path
    == eql? hash <=> === each call inspect as_json to_json
    deconstruct deconstruct_keys encode_with init_with yaml_initialize
  ].to_set
  METHOD_NAMES = RUNTIME_METHODS | PROTOCOL_METHODS
end
