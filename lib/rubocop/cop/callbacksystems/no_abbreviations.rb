# Prohibits common abbreviations in method, variable, and constant names.
#
# @example
#   # bad
#   def calc_total
#   end
#
#   # bad
#   attrs = {}
#
#   # bad
#   USER_ATTRS = %i[name email]
#
#   # good
#   def calculate_total
#   end
#
#   # good
#   attributes = {}
#
#   # good
#   USER_ATTRIBUTES = %i[name email]
#
class RuboCop::Cop::Callbacksystems::NoAbbreviations < RuboCop::Cop::Callbacksystems::Base
  ABBREVIATIONS = {
    "abbrev" => "abbreviation",
    "amt" => "amount",
    "attr" => "attribute",
    "attrs" => "attributes",
    "calc" => "calculate",
    "dest" => "destination",
    "doc" => "document",
    "docs" => "documents",
    "err" => "error",
    "errs" => "errors",
    "expr" => "expression",
    "func" => "function",
    "funcs" => "functions",
    "impl" => "implementation",
    "init" => "initialize",
    "libs" => "libraries",
    "msg" => "message",
    "msgs" => "messages",
    "num" => "number",
    "nums" => "numbers",
    "obj" => "object",
    "objs" => "objects",
    "opt" => "option",
    "opts" => "options",
    "org" => "organization",
    "orgs" => "organizations",
    "pkg" => "package",
    "pkgs" => "packages",
    "pos" => "position",
    "prev" => "previous",
    "procs" => "processes",
    "prop" => "property",
    "props" => "properties",
    "ref" => "reference",
    "refs" => "references",
    "repo" => "repository",
    "repos" => "repositories",
    "req" => "request",
    "reqs" => "requests",
    "res" => "response",
    "resp" => "response",
    "src" => "source",
    "str" => "string",
    "strs" => "strings",
    "tmp" => "temporary",
    "val" => "value",
    "vals" => "values",
    "var" => "variable",
    "vars" => "variables"
  }.freeze

  MESSAGE = "Avoid abbreviation `%<abbrev>s`. Use `%<full>s` instead."

  def on_def(node)
    check_abbreviations(node, node.method_name.to_s)
  end

  alias on_defs on_def

  def on_lvasgn(node)
    check_abbreviations(node, node.name.to_s)
  end

  def on_ivasgn(node)
    check_abbreviations(node, node.name.to_s.delete_prefix("@"))
  end

  def on_cvasgn(node)
    check_abbreviations(node, node.name.to_s.delete_prefix("@@"))
  end

  def on_casgn(node)
    check_abbreviations(node, node.name.to_s.downcase)
  end

  def on_arg(node)
    check_abbreviations(node, node.name.to_s)
  end

  alias on_optarg on_arg
  alias on_kwarg on_arg
  alias on_kwoptarg on_arg

  private
    def check_abbreviations(node, name)
      abbreviations_in(name).each do |abbreviation|
        add_offense(node, message: format(MESSAGE, abbrev: abbreviation, full: ABBREVIATIONS[abbreviation]))
      end
    end

    def abbreviations_in(name)
      name.split("_").select { ABBREVIATIONS.key?(it) }
    end
end
