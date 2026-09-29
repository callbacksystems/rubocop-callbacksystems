# Prohibits common abbreviations in declared names, including CamelCase. A
# full word costs a few keystrokes once and reads at a glance every time after,
# while an abbreviation makes every reader expand it.
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
#   # bad
#   class UserAttrs
#   end
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
#   # good
#   class UserAttributes
#   end
#
class RuboCop::Cop::Callbacksystems::NoAbbreviations < RuboCop::Cop::Callbacksystems::Base
  def on_class(node)
    on_def(node.identifier)
  end

  alias on_module on_class

  def on_def(node)
    report_each AbbreviatedName.new(node.loc.name)
  end

  alias on_defs on_def
  alias on_lvasgn on_def
  alias on_match_var on_def
  alias on_ivasgn on_def
  alias on_cvasgn on_def
  alias on_gvasgn on_def
  alias on_casgn on_def
  alias on_arg on_def
  alias on_optarg on_def
  alias on_restarg on_def
  alias on_kwarg on_def
  alias on_kwoptarg on_def
  alias on_kwrestarg on_def
  alias on_blockarg on_def
  alias on_shadowarg on_def

  private
    # Ruby and Rails conventions stay readable: params, args, id, ids, config, env, info, lib, max, min,
    # proc(s), temp, sync, and the attr_reader, attr_writer, and attr_accessor APIs.
    ABBREVIATIONS = {
      "abbrev" => "abbreviation",
      "amt" => "amount",
      "arr" => "array",
      "attr" => "attribute",
      "attrs" => "attributes",
      "btn" => "button",
      "buf" => "buffer",
      "calc" => "calculate",
      "cb" => "callback",
      "cfg" => "configuration",
      "cmd" => "command",
      "conf" => "configuration",
      "ctx" => "context",
      "curr" => "current",
      "decl" => "declaration",
      "decls" => "declarations",
      "dep" => "dependency",
      "deps" => "dependencies",
      "dest" => "destination",
      "doc" => "document",
      "docs" => %w[ documentation documents ],
      "elem" => "element",
      "elems" => "elements",
      "err" => "error",
      "errs" => "errors",
      "evt" => "event",
      "expr" => "expression",
      "exprs" => "expressions",
      "func" => "function",
      "funcs" => "functions",
      "ident" => "identifier",
      "idents" => "identifiers",
      "idx" => "index",
      "impl" => "implementation",
      "init" => "initialize",
      "len" => "length",
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
      "perf" => "performance",
      "pkg" => "package",
      "pkgs" => "packages",
      "pos" => "position",
      "prev" => "previous",
      "prop" => "property",
      "props" => "properties",
      "ref" => "reference",
      "refs" => "references",
      "repo" => "repository",
      "repos" => "repositories",
      "req" => "request",
      "reqs" => "requests",
      "res" => %w[ resource response result ],
      "resp" => "response",
      "sep" => "separator",
      "src" => "source",
      "stmt" => "statement",
      "stmts" => "statements",
      "str" => "string",
      "strs" => "strings",
      "tbl" => "table",
      "tmp" => "temporary",
      "val" => "value",
      "vals" => "values",
      "var" => "variable",
      "vars" => "variables",
      "ver" => "version"
    }

    # Word boundaries preserve acronyms and source offsets while recognizing both snake_case and CamelCase names.
    class AbbreviatedName
      MESSAGE = "Avoid abbreviation `%<abbreviation>s`. Use %<full>s instead."
      WORD_PATTERN = /[[:upper:]]+(?=[[:upper:]][[:lower:]]|[^[:alpha:]]|\z)|[[:upper:]]?[[:lower:]]+/
      NEXT_WORD_PATTERN = /\A_?(#{WORD_PATTERN})/
      ATTRIBUTE_ACCESSORS = %w[ accessor reader writer ]

      def initialize(range)
        @range = range
      end

      def each_offense
        range&.source&.scan(WORD_PATTERN) do
          match = Regexp.last_match
          if abbreviation_at?(match)
            yield RuboCop::Callbacksystems::Offense.new(location_of(match), message_for(match.to_s))
          end
        end
      end

      private
        attr_reader :range

        def abbreviation_at?(match)
          ABBREVIATIONS.key?(match.to_s.downcase) && !attribute_accessor_at?(match)
        end

        def attribute_accessor_at?(match)
          match.to_s.casecmp?("attr") && range.source[match.end(0)..].match(NEXT_WORD_PATTERN)&.then do |following|
            ATTRIBUTE_ACCESSORS.include?(following.captures.first.downcase)
          end
        end

        def location_of(match)
          range.with(begin_pos: range.begin_pos + match.begin(0), end_pos: range.begin_pos + match.end(0))
        end

        def message_for(word)
          format(MESSAGE, abbreviation: word, full: replacements_for(word))
        end

        def replacements_for(word)
          Array(ABBREVIATIONS[word.downcase]).map { "`#{replacement_for(word, with: it)}`" }.join(" or ")
        end

        def replacement_for(word, with:)
          if word == word.upcase
            with.upcase
          elsif word.start_with?(/[[:upper:]]/)
            with.capitalize
          else
            with
          end
        end
    end
end
