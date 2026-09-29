# Detects single-letter names for variables, block arguments, and method
# parameters. A single letter says nothing about what it holds, so a reader
# has to go back to where it was assigned to learn what `i` or `e` stands for,
# where a descriptive name answers on the spot.
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
    name = variable_name_of(node)
    add_offense(node, message: format(MESSAGE, name:)) if single_letter?(name)
  end

  alias on_arg on_lvasgn
  alias on_optarg on_lvasgn
  alias on_restarg on_lvasgn
  alias on_kwarg on_lvasgn
  alias on_kwoptarg on_lvasgn
  alias on_kwrestarg on_lvasgn
  alias on_blockarg on_lvasgn
  alias on_match_var on_lvasgn
  alias on_shadowarg on_lvasgn

  private
    def single_letter?(name)
      name && name.length == 1 && !name.start_with?("_")
    end
end
