# A method that returns a value should be named for the value it hands back
# (`total`, `user_by_id`), not for the imperative action it performs
# (`compute_total`, `get_user`). The imperative name reads as a command when the
# thing is really a query. We flag a method whose name leads with a producer verb.
# With no arguments we suggest the bare noun (`total`); with arguments we only
# flag it, because a bare noun beside an argument (`user(id)`) relates nothing and
# the relator, a suffix (`_for`/`_of`/`_at`/...), is the author's call, too
# contextual to pick.
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
# that calls `save!`, `build_answers_from` that iterates filling answers, an
# association `build` that mutates the collection. Construction is delivery, not
# doing: `Foo.new(args)` only hands a value back, so a pure factory is flagged.
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
#   # bad - bare producer verb names nothing
#   def compute
#     heavy_work
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

  # Prepositions that relate a returned value to a method's arguments
  # (`user_for(id)`, `node_at(i)`, `scope_from(node)`). An open class; this is
  # the common core, enough to tell a relating name from a bare one.
  CONNECTORS = %w[
    for of from at in on by with within without
    into onto over under above below beneath behind
    beside before after between across through throughout
    toward towards alongside during via to per until
    since against among around near beyond
  ].to_set.freeze

  # Method names that change state in place, plus iteration for effect. A
  # producer-verb method calling one (or assigning to @ivar/@@cvar/$global) is
  # doing something, not just delivering a value.
  MUTATORS = %i[
    save update create build destroy delete insert push concat append remove clear
    each each_with_index puts print pp write
    touch mkdir mkdir_p mkpath makedirs rm rm_f rm_rf rmdir remove_entry remove_dir
    cp cp_r mv ln_s chmod chown
  ].to_set.freeze

  IMPERATIVE_NAME = "Rename `%<name>s` to `%<suggestion>s`: name it for the value, not the action `%<verb>s`."
  IMPERATIVE_NAME_RELATE = "Rename `%<name>s` for the value, related to its argument, not the action `%<verb>s`."
  IMPERATIVE_NAME_BARE = "Rename `%<name>s`: it names the imperative `%<verb>s` action, not the value it returns."

  def on_def(node)
    producer = Producer.new(node)
    add_offense(node.loc.name, message: producer.offense_message) if producer.offense?
  end

  alias on_defs on_def

  private
    # A method judged against the producer-verb set: reads as a command when its
    # name leads with a producer verb.
    class Producer
      def initialize(node)
        @node = node
      end

      def offense?
        eligible? && PRODUCER_VERBS.include?(verb) && delivers_only?
      end

      def offense_message
        format(message_template, name: node.method_name, verb: verb, suggestion: noun)
      end

      private
        attr_reader :node

        # Predicates, bang methods, setters, operators, and `initialize` are owned
        # by Ruby convention; a producer-verb query name never applies to them.
        def eligible?
          !node.predicate_method? && !node.bang_method? && !node.assignment_method? &&
            !node.operator_method? && !node.method?(:initialize)
        end

        def verb
          segments.first
        end

        def segments
          @segments ||= node.method_name.to_s.split("_")
        end

        # Ruby always returns its last expression, so "delivers" is the absence of
        # effects: it changes no state, calls no mutator, does no I/O.
        def delivers_only?
          node.each_descendant(:ivasgn, :cvasgn, :gvasgn, :casgn, :send).none? { side_effect?(it) }
        end

        def side_effect?(descendant)
          descendant.send_type? ? mutating_send?(descendant) : true
        end

        def mutating_send?(send)
          send.bang_method? || send.setter_method? || MUTATORS.include?(send.method_name)
        end

        def message_template
          if !noun
            IMPERATIVE_NAME_BARE
          elsif needs_relator?
            IMPERATIVE_NAME_RELATE
          else
            IMPERATIVE_NAME
          end
        end

        # The verb-stripped noun, or nil when there is none (`compute`) or it
        # leads with a connector, leaving a prepositional phrase that names
        # nothing on its own (`find_in_block`).
        def noun
          rest.join("_") if rest.any? && !CONNECTORS.include?(rest.first)
        end

        def rest
          segments.drop(1)
        end

        # A value built from an argument should relate to it; a bare noun
        # (`user(id)`) does not, unless its name already carries a connector
        # (`user_by_id`).
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
