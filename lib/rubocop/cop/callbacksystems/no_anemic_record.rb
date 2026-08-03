# A hash of three or more keys, built in one place and read from several others,
# is a data clump wearing braces. Every caller reaches past it to its keys
# (`context[:account]`) because it has no methods of its own, so the same refactor
# applies: give it a class, and the methods reading its keys become its methods.
#
# The distinction that matters is whether the hash travels. One built and consumed
# on the spot, an options argument or a payload handed straight to a call, is a
# value, not a concept; only a hash that is named or returned, and whose keys are
# then read from more than one method, is reported.
#
# DataClump sees the same smell spelled as parameter lists. Bagging a clump into a
# hash silences that cop without changing anything, so this one closes the gap:
# both spellings report, and the way out of either is the class.
#
# @example
#   # bad - built once, reached into from everywhere
#   def context
#     { account: account, plan: plan, seats: seats }
#   end
#
#   def price
#     context[:plan].price * context[:seats]
#   end
#
#   def label
#     "#{context[:account].name} (#{context[:plan].name})"
#   end
#
#   # good - the readers become its methods
#   class Context
#     def initialize(account, plan, seats)
#       @account, @plan, @seats = account, plan, seats
#     end
#
#     def price
#       plan.price * seats
#     end
#
#     def label
#       "#{account.name} (#{plan.name})"
#     end
#
#     private
#       attr_reader :account, :plan, :seats
#   end
#
class RuboCop::Cop::Callbacksystems::NoAnemicRecord < RuboCop::Cop::Callbacksystems::Base
  MESSAGE = "This hash carries `%<fields>s` and no behaviour, and %<count>d methods reach into its keys. " \
    "That is one concept: give it a class and let those become its methods."

  def on_new_investigation
    FileRecords.new(processed_source.ast, cop_config).each_offense do |node, message|
      add_offense(node, message: message)
    end
  end

  private
    class FileRecords
      def initialize(ast, cop_config)
        @ast = ast
        @cop_config = cop_config
      end

      def each_offense(&block)
        if block
          records.each { yield it.node, it.message if it.offense? }
        else
          to_enum(__method__)
        end
      end

      private
        attr_reader :ast, :cop_config

        # Best match first, so a narrow hash keeps its own reaches instead of being
        # swallowed by a wider one that happens to contain its keys.
        def records
          @records ||= candidates.each { it.claim(reaches_owned_by(it)) }
        end

        def candidates
          @candidates ||= ast ? ast.each_node(:hash).map { Record.new(it, limits) } : []
        end

        def limits
          Limits.new(min_fields: cop_config["MinFields"], min_readers: cop_config["MinReaders"])
        end

        def reaches_owned_by(record)
          reaches.select { best_match_for(it.base).equal?(record) }
        end

        def reaches
          @reaches ||= ast ? ast.each_node(:send).flat_map { Reach.new(it).reads } : []
        end

        def best_match_for(base)
          best_matches[base] ||= strongest_for(fields_reached_on(base))
        end

        def best_matches
          @best_matches ||= {}
        end

        # Under two shared keys is a coincidence of vocabulary, not the same hash.
        def strongest_for(reached)
          candidates.map { [ it, it.match_for(reached) ] }
            .select { it.last.strong? }
            .min_by { it.last.rank }
            &.first
        end

        def fields_reached_on(base)
          reaches.select { it.on?(base) }.to_set(&:field)
        end
    end

    Limits = Data.define(:min_fields, :min_readers)

    class Match < Data.define(:shared, :fit)
      MIN_SHARED_FIELDS = 2

      def strong?
        shared >= MIN_SHARED_FIELDS
      end

      def rank
        [ -shared, -fit ]
      end
    end

    class Record
      include RuboCop::Callbacksystems::Helpers

      attr_reader :node

      def initialize(node, limits)
        @node = node
        @limits = limits
        @reaches = []
      end

      def claim(reaches)
        @reaches = reaches
      end

      def match_for(reached)
        shared = fields.count { reached.include?(it) }
        Match.new(shared: shared, fit: shared.fdiv(fields.size))
      end

      def offense?
        plain_record? && travels? && reader_count >= limits.min_readers
      end

      def message
        format(MESSAGE, fields: fields.sort.join(", "), count: reader_count)
      end

      private
        attr_reader :limits, :reaches

        def fields
          @fields ||= node.children.select { data_pair?(it) }.map { it.key.value.to_s }
        end

        def data_pair?(pair)
          pair.pair_type? && pair.key.sym_type? && !pair.value.any_block_type?
        end

        # A callable value makes it an object already; a double-splat means the shape
        # is not this literal's to own.
        def plain_record?
          fields.size >= limits.min_fields && node.children.all? { data_pair?(it) }
        end

        # A hash consumed where it is built is a value, not a concept.
        def travels?
          assigned? || returned?
        end

        def assigned?
          named.parent&.assignment?
        end

        # A record bound to a constant is usually frozen first, so `freeze` is the
        # parent rather than the assignment.
        def named
          frozen? ? node.parent : node
        end

        def frozen?
          node.parent&.send_type? && node.parent.method?(:freeze)
        end

        def returned?
          named.parent&.return_type? || implicitly_returned?
        end

        def implicitly_returned?
          body = enclosing_method&.body
          body && last_statement_in(body).equal?(named)
        end

        def enclosing_method
          node.each_ancestor(:any_def).first
        end

        # Scattering is the symptom, so each consumer counts once however many keys
        # it reaches for.
        def reader_count
          @reader_count ||= key_reaches.map(&:reader).uniq.size
        end

        def key_reaches
          reaches.select { fields.include?(it.field) }.reject { it.inside?(node) }
        end
    end

    class Reach
      READERS = %i[[] fetch dig].freeze

      def initialize(node)
        @node = node
      end

      def reads
        key_read? ? [ Read.new(base_name, node.first_argument.value.to_s, node) ] : []
      end

      private
        attr_reader :node

        def key_read?
          READERS.include?(node.method_name) && symbol_key_on_named_base?
        end

        def symbol_key_on_named_base?
          node.arguments.one? && node.first_argument.sym_type? && base_name.present?
        end

        # A bare call names the hash too: the Ruby way to build one here and read it
        # there is a memoized method, not a binding.
        def base_name
          @base_name ||= named_base_of(node.receiver)
        end

        def named_base_of(receiver)
          if receiver&.type?(:lvar, :ivar)
            receiver.children.first.to_s
          elsif receiver&.const_type?
            receiver.short_name.to_s
          elsif bare_call?(receiver)
            receiver.method_name.to_s
          end
        end

        def bare_call?(receiver)
          receiver&.send_type? && receiverless?(receiver)
        end

        def receiverless?(receiver)
          receiver.receiver.nil? && receiver.arguments.empty?
        end
    end

    class Read < Data.define(:base, :field, :node)
      def on?(other)
        base == other
      end

      def inside?(other)
        other.source_range.contains?(node.source_range)
      end

      # Reaches at file level share one reader.
      def reader
        node.each_ancestor(:any_def).first
      end
    end
end
