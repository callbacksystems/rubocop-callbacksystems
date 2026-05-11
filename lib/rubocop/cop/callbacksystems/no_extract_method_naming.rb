# Detects methods named with "extract_" prefix.
# Such imperative names should be replaced with more descriptive alternatives.
#
# @example
#   # bad - imperative "extract" naming
#   def extract_job_class_name(node)
#   end
#
#   # good - pick the suffix that fits the context
#   def job_class_name_for(node)
#   def job_class_name_from(node)
#   def job_class_name_in(node)
#   def job_class_name_at(node)
#   def job_class_name # sometimes no suffix is needed
#
class RuboCop::Cop::Callbacksystems::NoExtractMethodNaming < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Avoid `extract_*` method names. Consider `%<name>s_for`, `%<name>s_from`, `%<name>s_in`, `%<name>s_at`, or just `%<name>s`."
  EXTRACT_PREFIX = /\Aextract_(.+)\z/

  def on_def(node)
    EXTRACT_PREFIX.match(node.method_name.to_s) do |match_data|
      next if match_data.captures.first.empty?

      add_offense(node.loc.name, message: format(MESSAGE, name: match_data.captures.first))
    end
  end

  alias on_defs on_def
end
