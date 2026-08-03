# A method that returns a value should be named for the value it hands back, not
# for the imperative action it performs. `compute_total` is really `total` and
# `get_user` is `user_by_id`: the imperative name reads as a command when the
# thing is really a query. We flag a method whose name leads with a producer verb
# and carries a noun we can rename it to (`compute_total` -> `total`). A bare verb
# (`fetch`) is left alone: with no noun there is nothing to rename to. A verb
# followed straight by a connector (`find_in_scope`, `load_for`) is left alone
# too: the phrase that remains (`in_scope`, `for`) names no value on its own, and
# the leading word often reads as a noun in context (`load_for person` is "the
# load for a person"), so the rename is too contextual to pick. With arguments and
# no connector in the name we only flag it (`get_user(id)`): a bare noun beside an
# argument (`user(id)`) relates nothing, and the relator is the author's call.
#
# The verb list is curated, not taken from a lexicon: `get`/`find`/`build` are not
# dropped from any dictionary, but are bad as method prefixes by code convention.
# Excluded on purpose: noun-verbs that name a value fine (`count`, `name`,
# `value`, `order`, `state`...) and command verbs that act rather than produce
# (`save`, `render`, `update`, `send`, `handle`, `process`...).
#
# We flag a producer-verb method only when it just *delivers* a value: it
# changes no state, calls no mutator, does no I/O. A method that *does* something
# earns its verb and is left alone, even named with a producer verb: `create_user`
# that calls `save!`, an association `build` that mutates the collection.
# Construction is delivery, not doing: `Foo.new(args)` only hands a value back, so
# a pure factory is flagged.
#
# Two more cases are left alone, both signs the name is intentional rather than
# careless. A method that delegates within its own verb family (`format_money`
# calling `format_short`, `find_account_by_cookie` calling `find_by`) mirrors a
# real operation of the same name, so renaming it would break the family. And a
# method whose suggested noun already names a sibling (`build_prices` beside
# `attr_reader :prices`, `lookup_key` beside `key`) is the separate-builder
# pattern: the value already has its declarative name, this is its helper.
#
# Ruby divergence from the JS rule: JS can gate on "returns a value" because a
# function can fall off the end returning `undefined`. In Ruby every method
# returns its last expression, so "delivers" is the *absence of effects*, not the
# presence of a return. Predicates (`valid?`), bang methods (`save!`), setters
# (`foo=`), operators, and `initialize` stay exempt by Ruby convention.
#
# @example
#   # bad - imperative name for a value (no arguments): name it for the value
#   def compute_total
#     line_items.sum(&:price)
#   end
#
#   # bad - imperative name for a value built from an argument
#   def get_user(id)
#     users[id]
#   end
#
#   # good - the bare verb is allowed: there is no noun to rename it to
#   def compute
#     heavy_work
#   end
#
#   # good - verb followed straight by a connector names no value to rename to
#   def load_for(person)
#     events_for(person) + blocks_for(person)
#   end
#
#   # good - delegates within its own verb family: it mirrors a real operation
#   def format_money(money)
#     Worldwide.currency(money).format_short(money)
#   end
#
#   # good - the suggested noun already names a sibling (`attr_reader :prices`)
#   def build_prices
#     properties.to_h { |currency, cents| [ currency, Money.new(cents) ] }
#   end
#
#   # good - named for the value it returns
#   def total
#     line_items.sum(&:price)
#   end
#
#   # good - noun-verb reads as a noun
#   def count
#     items.length
#   end
#
#   # good - predicates, bang methods, and setters are exempt by convention
#   def valid?
#     errors.empty?
#   end
#
class RuboCop::Cop::Callbacksystems::DeclarativeMethodNaming < RuboCop::Cop::Callbacksystems::Base
  PRODUCER_VERBS = %w[
    get fetch retrieve obtain acquire load
    compute calculate derive determine evaluate deduce infer
    generate produce fabricate assemble construct build make create
    convert transform translate cast coerce
    serialize deserialize stringify normalize denormalize parse extract
    format summarize aggregate tabulate
    find lookup locate search select pick choose
    collect gather accumulate compile
    resolve
  ].to_set.freeze

  # An open class; this is the common core, enough to tell a relating name from
  # a bare one.
  CONNECTORS = %w[
    for of from at in on by with within without
    into onto over under above below beneath behind
    beside before after between across through throughout
    toward towards alongside during via to per until
    since against among around near beyond
  ].to_set.freeze

  # A producer-verb method calling one is doing something, not delivering a
  # value.
  MUTATORS = %i[
    save update create build destroy delete insert
    push pop shift unshift prepend concat append << store replace add clear
    each each_with_index puts print pp write
    touch mkdir mkdir_p mkpath makedirs rm rm_f rm_rf rmdir remove_entry remove_dir
    cp cp_r mv ln_s chmod chown
  ].to_set.freeze

  # A producer-verb method whose noun matches one of these is that value's
  # separate builder.
  READER_MACROS = %i[attr_reader attr_accessor attr_writer].to_set.freeze

  IMPERATIVE_NAME = "Rename `%<name>s` to `%<suggestion>s`: name it for the value, not the action `%<verb>s`."
  IMPERATIVE_NAME_RELATE = "Rename `%<name>s` for the value, related to its argument, not the action `%<verb>s`."

  def on_def(node)
    producer = Producer.new(node)
    add_offense(node.loc.name, message: producer.offense_message) if producer.offense?
  end

  alias on_defs on_def

  private
    class Producer
      def initialize(node)
        @node = node
      end

      def offense?
        eligible? && imperative_producer? && delivers_only? &&
          !delegates_within_verb_family? && !value_already_named?
      end

      def offense_message
        format(message_template, name: node.method_name, verb: verb, suggestion: noun)
      end

      private
        attr_reader :node

        # These names are owned by Ruby convention.
        def eligible?
          !node.predicate_method? && !node.bang_method? && !node.assignment_method? &&
            !node.operator_method? && !node.method?(:initialize)
        end

        # A bare verb (`fetch`) and a verb glued to a connector (`load_for`) leave no
        # noun to rename to.
        def imperative_producer?
          PRODUCER_VERBS.include?(verb) && !noun.nil?
        end

        def verb
          segments.first
        end

        def segments
          @segments ||= node.method_name.to_s.split("_")
        end

        # Nil when the name leads with a connector, leaving a prepositional phrase
        # that names nothing on its own (`find_in_block`).
        def noun
          rest.join("_") if rest.any? && !CONNECTORS.include?(rest.first)
        end

        def rest
          segments.drop(1)
        end

        # Ruby always returns its last expression, so delivering is the absence of
        # effects.
        def delivers_only?
          node.each_descendant(:ivasgn, :cvasgn, :gvasgn, :casgn, :send).none? { side_effect?(it) }
        end

        def side_effect?(descendant)
          descendant.send_type? ? mutating_send?(descendant) : true
        end

        def mutating_send?(send)
          send.bang_method? || send.setter_method? || MUTATORS.include?(send.method_name)
        end

        # The name mirrors a real operation of the same name, so it is intentional.
        def delegates_within_verb_family?
          node.each_descendant(:send).any? { it.method_name.to_s.split("_").first == verb }
        end

        def value_already_named?
          container&.each_descendant(:any_def, :send)&.any? { names_value?(it) } || false
        end

        def container
          node.each_ancestor(:class, :module, :sclass).first
        end

        def names_value?(relative)
          if relative.any_def_type?
            relative.method_name.to_s == noun
          else
            reader_macro_for_noun?(relative)
          end
        end

        def reader_macro_for_noun?(send)
          READER_MACROS.include?(send.method_name) &&
            send.arguments.any? { it.sym_type? && it.value.to_s == noun }
        end

        def message_template
          needs_relator? ? IMPERATIVE_NAME_RELATE : IMPERATIVE_NAME
        end

        # A bare noun (`user(id)`) does not relate to its argument, unless the name
        # already carries a connector (`user_by_id`).
        def needs_relator?
          arguments? && !carries_connector?
        end

        def arguments?
          node.arguments.any?
        end

        def carries_connector?
          rest.any? { CONNECTORS.include?(it) }
        end
    end
end
