# A method that returns a value should be named for the value it hands back
# (`total`, `user_by_id`), not for the imperative action it performs
# (`compute_total`, `get_user`). The imperative name reads as a command when the
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
# a pure factory is flagged. Building a collaborator and then asking it for
# something is a third case: what happens inside is not readable here, so
# `Commenter.new(card).comment` leaves the name alone.
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
  def on_new_investigation
    @declared_values = DeclaredValues.new
  end

  def on_def(node)
    report MethodName.new(node, declared_values:)
  end

  alias on_defs on_def

  private
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
    ].to_set

    CONNECTORS = %w[
      for of from at in on by with within without
      into onto over under above below beneath behind
      beside before after between across through throughout
      toward towards alongside during via to per until
      since against among around near beyond
    ].to_set

    EFFECTS = %i[
      save update create build destroy delete insert
      insert_all upsert upsert_all update_all delete_all destroy_all
      push pop shift unshift prepend concat append << store replace add clear
      each each_with_index puts print pp write
      touch mkdir mkdir_p mkpath makedirs rm rm_f rm_rf rmdir remove_entry remove_dir
      cp cp_r mv ln_s chmod chown
    ].to_set

    READER_MACROS = %i[ attr_reader attr_accessor attr_writer ].to_set
    SIDE_EFFECT_NODE_TYPES = %i[ casgn cvasgn gvasgn ivasgn super xstr yield zsuper ]
    NETWORK_METHODS = %i[ get post put patch delete request start ].to_set
    FILESYSTEM_RECEIVERS = %w[ File IO ].to_set
    FILESYSTEM_METHODS = %i[ binread foreach open read readlines sysopen ].to_set

    attr_reader :declared_values

    # Value names indexed once for each body whose methods ask whether their suggested noun is already taken.
    class DeclaredValues
      include RuboCop::Callbacksystems::Helpers

      def initialize
        @sibling_methods = RuboCop::Callbacksystems::Methods::Siblings.new
        @reader_names_by_container = {}.compare_by_identity
      end

      def include?(name, beside:)
        sibling_methods.named(name.to_sym, beside:).any? || reader_names_beside(beside).include?(name)
      end

      private
        attr_reader :sibling_methods, :reader_names_by_container

        def reader_names_beside(method)
          domain = RuboCop::Callbacksystems::Methods::Domain.new(method)
          reader_names_in(domain.container).fetch(domain.identity) { Set.new }
        end

        def reader_names_in(container)
          if container
            reader_names_by_container[container] ||=
              ReaderMacros.new(container.body).each_with_object({}) do |macro, names|
                (names[declaration_domain_of(macro)] ||= Set.new)
                  .merge(macro.arguments.select(&:sym_type?).map { it.value.to_s })
              end
          else
            {}
          end
        end

        def declaration_domain_of(macro)
          identity = RuboCop::Callbacksystems::Methods::Domain.new(macro).identity
          identity.take(identity.size.pred).freeze
        end

        # Reader declarations reached through body sequences, singleton sections, and nested call arguments.
        class ReaderMacros
          include Enumerable
          include RuboCop::Callbacksystems::Helpers

          def initialize(body)
            @body = body
          end

          def each
            if block_given?
              @pending = [ body ].compact
              until pending.empty?
                advance
                visit { yield it }
              end
            else
              to_enum(__method__)
            end
          end

          private
            attr_reader :body, :pending, :current

            def advance
              @current = pending.pop
            end

            def visit
              case current.type
              when :begin, :kwbegin then queue current.each_child_node
              when :sclass then queue [ current.body ].compact
              when :send then visit_send { yield it }
              end
            end

            def queue(nodes)
              pending.concat(nodes.to_a.reverse)
            end

            def visit_send
              yield current if reader_macro?
              queue current.arguments
            end

            def reader_macro?
              bare_send?(current) && READER_MACROS.include?(current.method_name)
            end
        end
    end

    class MethodName
      include RuboCop::Callbacksystems::Helpers

      IMPERATIVE_NAME = "Rename `%<name>s` to `%<suggestion>s`: name it for the value, not the action `%<verb>s`."
      IMPERATIVE_NAME_RELATE = "Rename `%<name>s` for the value, related to its argument, not the action `%<verb>s`."

      def initialize(node, declared_values:)
        @node = node
        @declared_values = declared_values
      end

      def offense
        RuboCop::Callbacksystems::Offense.new(node.loc.name, message) if imperatively_named?
      end

      private
        attr_reader :node, :declared_values

        def imperatively_named?
          eligible? && imperative_producer? && delivers_only? &&
            !delegates_within_verb_family? && !value_already_named?
        end

        def eligible?
          !node.predicate_method? && !node.bang_method? && !node.assignment_method? &&
            !node.operator_method? && !node.method?(:initialize)
        end

        def imperative_producer?
          PRODUCER_VERBS.include?(verb) && !noun.nil?
        end

        def verb
          segments.first
        end

        def segments
          @segments ||= node.method_name.to_s.split("_")
        end

        # A rest led by a connector (`find_in_block`) is a prepositional phrase naming nothing, so it yields no noun.
        def noun
          rest.join("_") if rest.any? && CONNECTORS.exclude?(rest.first)
        end

        def rest
          segments.drop(1)
        end

        def delivers_only?
          RuboCop::Callbacksystems::Execution::Immediate.new(node.body).none? do |descendant|
            descendant.type?(*SIDE_EFFECT_NODE_TYPES, :call) && SideEffect.new(descendant).present?
          end
        end

        def delegates_within_verb_family?
          node.each_descendant(:call).any? { it.method_name.to_s.split("_").first == verb }
        end

        def value_already_named?
          declared_values.include?(noun, beside: node)
        end

        def message
          format(message_template, name: node.method_name, verb: verb, suggestion: noun)
        end

        def message_template
          needs_relator? ? IMPERATIVE_NAME_RELATE : IMPERATIVE_NAME
        end

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

    class SideEffect
      include RuboCop::Callbacksystems::Helpers

      def initialize(node)
        @node = node
      end

      def present?
        !node.call_type? || mutating_call?
      end

      private
        attr_reader :node

        def mutating_call?
          node.bang_method? || node.setter_method? || EFFECTS.include?(node.method_name) ||
            asks_a_built_collaborator? || performs_io?
        end

        def asks_a_built_collaborator?
          node.receiver&.call_type? && node.receiver.method?(:new)
        end

        def performs_io?
          performs_network_io? || performs_filesystem_io?
        end

        def performs_network_io?
          receiver_constant.to_s.start_with?("Net::HTTP") && NETWORK_METHODS.include?(node.method_name)
        end

        def receiver_constant
          @receiver_constant ||= constant_name_of(node.receiver)&.delete_prefix("::")
        end

        def performs_filesystem_io?
          FILESYSTEM_RECEIVERS.include?(receiver_constant) && FILESYSTEM_METHODS.include?(node.method_name)
        end
    end
end
