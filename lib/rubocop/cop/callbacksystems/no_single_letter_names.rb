# Detects single-letter names for variables, block arguments, and method
# parameters. Names should be descriptive, not single characters.
#
# @example
#   # bad
#   x = 5
#   items.each { |i| process(i) }
#   def foo(n); end
#   items.map { |e| e.name }
#   hash.each { |k, v| puts k }
#
#   # good
#   count = 5
#   items.each { |item| process(item) }
#   def foo(number); end
#   items.map { |element| element.name }
#   hash.each { |key, value| puts key }
#
#   # ok - underscore convention for unused
#   items.each { |_| process }
#   [1,2].each_with_index { |_, index| puts index }
#
class RuboCop::Cop::Callbacksystems::NoSingleLetterNames < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "Avoid single-letter name `%<name>s`. Use a descriptive name instead."

  def on_lvasgn(node)
    name = node.children.first.to_s
    add_offense(node, message: format(MESSAGE, name: name)) if name.length == 1 && !name.start_with?("_")
  end

  alias on_arg on_lvasgn
  alias on_optarg on_lvasgn
  alias on_restarg on_lvasgn
  alias on_kwarg on_lvasgn
  alias on_kwoptarg on_lvasgn
  alias on_kwrestarg on_lvasgn
  alias on_blockarg on_lvasgn
end
