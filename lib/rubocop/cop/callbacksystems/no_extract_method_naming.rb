# Detects methods named with "extract_" prefix.
# Such imperative names should be replaced with more descriptive alternatives.
#
# @example
#   # bad - imperative "extract" naming
#   def extract_job_class_name(node)
#     # ...
#   end
#
#   # good - descriptive with "_for" suffix
#   def job_class_name_for(node)
#     # ...
#   end
#
#   # bad
#   def extract_user_id(params)
#     # ...
#   end
#
#   # good
#   def user_id_from(params)
#     # ...
#   end
#
class RuboCop::Cop::Callbacksystems::NoExtractMethodNaming < RuboCop::Cop::Base
  MESSAGE = "Avoid `extract_*` method names. Use `%<suggestion>s` instead."
  EXTRACT_PREFIX = /\Aextract_(.+)\z/

  def on_def(node)
    EXTRACT_PREFIX.match(node.method_name.to_s) do |match_data|
      suggestion = "#{match_data.captures.first}_for"
      add_offense(node.loc.name, message: format(MESSAGE, suggestion: suggestion))
    end
  end

  alias on_defs on_def
end
