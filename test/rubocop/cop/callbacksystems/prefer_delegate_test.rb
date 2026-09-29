require "test_helper"

class RuboCop::Cop::Callbacksystems::PreferDelegateTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PreferDelegate

  test "registers offense for a private method delegating to a same-named method" do
    assert_offense <<~RUBY
      class Foo
        private
          def size
            node.size
          end
      end
    RUBY
  end

  test "registers offense for a private predicate delegation" do
    assert_offense <<~RUBY
      class Foo
        private
          def operator_method?
            node.operator_method?
          end
      end
    RUBY
  end

  test "registers offense for a private nested delegation" do
    offenses = assert_offense <<~RUBY
      class Foo
        private
          def database_names
            config.postgres.database_names
          end
      end
    RUBY

    assert_includes offenses.first.message, "config.postgres"
  end

  test "registers offense for a private delegation through explicit self" do
    assert_offense <<~RUBY
      class Foo
        private
          def size
            self.node.size
          end
      end
    RUBY
  end

  test "registers offense for a public nested delegation" do
    assert_offense <<~RUBY
      class Foo
        def database_names
          config.postgres.database_names
        end
      end
    RUBY
  end

  test "allows a nested delegation whose chain takes arguments" do
    assert_no_offense <<~RUBY
      class Foo
        def database_names
          config(scope).postgres.database_names
        end
      end
    RUBY
  end

  test "allows a nested delegation rooted at an instance variable" do
    assert_no_offense <<~RUBY
      class Foo
        def database_names
          @config.postgres.database_names
        end
      end
    RUBY
  end

  test "autocorrects a private nested delegation to a dotted target" do
    assert_correction \
      <<~RUBY,
        class Foo
          private
            def database_names
              config.postgres.database_names
            end
        end
      RUBY
      <<~RUBY
        class Foo
          private
            delegate :database_names, to: "config.postgres", private: true
        end
      RUBY
  end

  test "autocorrects a public nested delegation without the private option" do
    assert_correction \
      <<~RUBY,
        class Foo
          attr_reader :config

          def database_names
            config.postgres.database_names
          end
        end
      RUBY
      <<~RUBY
        class Foo
          attr_reader :config
          delegate :database_names, to: "config.postgres"
        end
      RUBY
  end

  test "writes a new delegate below an attribute declaration" do
    assert_correction \
      <<~RUBY,
        class Foo
          attribute :config

          def database_names
            config.postgres.database_names
          end
        end
      RUBY
      <<~RUBY
        class Foo
          attribute :config
          delegate :database_names, to: "config.postgres"
        end
    RUBY
  end

  test "leaves a documented delegation for a human rather than orphaning its comment" do
    assert_uncorrectable_offense <<~RUBY
      class Foo
        attr_reader :config

        # Returns the databases visible to this account.
        def database_names
          config.postgres.database_names
        end
      end
    RUBY
  end

  test "leaves a delegation with an internal comment for a human rather than dropping it" do
    assert_uncorrectable_offense <<~RUBY
      class Foo
        attr_reader :config

        def database_names
          # The primary cluster owns the canonical list.
          config.postgres.database_names
        end
      end
    RUBY
  end

  test "folds into an existing dotted delegate" do
    assert_correction \
      <<~RUBY,
        class Foo
          private
            delegate :names, to: "config.postgres", private: true

            def database_names
              config.postgres.database_names
            end
        end
      RUBY
      <<~RUBY
        class Foo
          private
            delegate :names, :database_names, to: "config.postgres", private: true
        end
      RUBY
  end

  test "writes a new delegate below the mixins when no declaration precedes the method" do
    assert_correction \
      <<~RUBY,
        class Foo
          include Enumerable

          def each(&block)
            blocks.each(&block)
          end
        end
      RUBY
      <<~RUBY
        class Foo
          include Enumerable

          delegate :each, to: :blocks
        end
      RUBY
  end

  test "leaves a public delegation in place when nothing anchors the macro" do
    source = <<~RUBY
      class Foo
        def database_names
          config.postgres.database_names
        end
      end
    RUBY

    assert_no_correction source
    assert_nil assert_offense(source).first.corrector
  end

  test "registers offense for a public method that only forwards its block" do
    assert_offense <<~RUBY
      class Foo
        def each(&block)
          blocks.each(&block)
        end
      end
    RUBY
  end

  test "registers offense for a forwarded anonymous block" do
    assert_offense <<~RUBY
      class Foo
        def each(&)
          blocks.each(&)
        end
      end
    RUBY
  end

  test "allows a method that takes a block without forwarding it" do
    assert_no_offense <<~RUBY
      class Foo
        def each(&block)
          blocks.each
        end
      end
    RUBY
  end

  test "allows a method that forwards a different block" do
    assert_no_offense <<~RUBY
      class Foo
        def each(&block)
          blocks.each(&fallback)
        end
      end
    RUBY
  end

  test "allows public delegations (handled by Rails/Delegate)" do
    assert_no_offense <<~RUBY
      class Foo
        def size
          node.size
        end
      end
    RUBY
  end

  test "allows a method that transforms instead of delegating purely" do
    assert_no_offense <<~RUBY
      class Foo
        private
          def count
            node.size
          end
      end
    RUBY
  end

  test "registers offense for a private method forwarding its own parameters" do
    assert_offense <<~RUBY
      class Foo
        private
          def fetch(key)
            node.fetch(key)
          end
      end
    RUBY
  end

  test "allows a public method forwarding its own parameters (handled by Rails/Delegate)" do
    assert_no_offense <<~RUBY
      class Foo
        def fetch(key)
          node.fetch(key)
        end
      end
    RUBY
  end

  test "allows delegation whose receiver takes arguments" do
    assert_no_offense <<~RUBY
      class Foo
        private
          def size
            node(scope).size
          end
      end
    RUBY
  end

  test "allows delegation to an instance variable" do
    assert_no_offense <<~RUBY
      class Foo
        private
          def size
            @node.size
          end
      end
    RUBY
  end

  test "registers offense for a private delegation to a constant" do
    offenses = assert_offense <<~RUBY
      class Charge
        private
          def subunit_factor(currency)
            Currency.subunit_factor(currency)
          end
      end
    RUBY

    assert_includes offenses.first.message, "delegate :subunit_factor, to: Currency, private: true"
    assert_not_includes offenses.first.message, "pass the arguments"
  end

  test "registers offense for a public delegation to a constant forwarding its block" do
    assert_offense <<~RUBY
      class Charge
        include Enumerable

        def each(&block)
          Registry.each(&block)
        end
      end
    RUBY
  end

  test "registers offense with the full namespace of a constant" do
    offenses = assert_offense <<~RUBY
      class Charge
        private
          def subunit_factor
            Pay::Mercadopago::Currency.subunit_factor(options[:currency])
          end
      end
    RUBY

    assert_includes offenses.first.message, "to: Pay::Mercadopago::Currency"
    assert_includes offenses.first.message, "pass the arguments at the call sites"
  end

  test "registers offense for an endless delegation" do
    assert_offense <<~RUBY
      class Charge
        private
          def subunit_factor = Currency.subunit_factor(currency)
      end
    RUBY
  end

  test "allows a public delegation to a constant (handled by Rails/Delegate)" do
    assert_no_offense <<~RUBY
      class Charge
        def subunit_factor(currency)
          Currency.subunit_factor(currency)
        end
      end
    RUBY
  end

  test "allows a wrapper combining its parameters with data of its own" do
    assert_no_offense <<~RUBY
      class ChargeTest
        private
          def parse(raw)
            WALPressure.parse(raw, slot_names: SLOTS)
          end
      end
    RUBY
  end

  test "allows a wrapper transforming its parameters" do
    assert_no_offense <<~RUBY
      class ChargeTest
        private
          def parse(*rows)
            Observation.parse(rows.join("\\n"))
          end
      end
    RUBY
  end

  test "allows a wrapper giving its parameters defaults" do
    assert_no_offense <<~RUBY
      class ChargeTest
        private
          def generate(key: "strong key", purpose: "verify")
            Fingerprint.generate(key: key, purpose: purpose)
          end
      end
    RUBY
  end

  test "allows a public wrapper binding its own state, whose callers are not all in view" do
    assert_no_offense <<~RUBY
      class Backup
        desc "create", "Trigger a backup"
        option :type, type: :string

        def create
          backup.create(type: options[:type])
        end
      end
    RUBY
  end

  test "registers offense for a delegation made private in its own definition" do
    offenses = assert_offense <<~RUBY
      class Foo
        private def fetch(key)
          registry.fetch(key)
        end
      end
    RUBY

    assert_includes offenses.first.message, "private: true"
  end

  test "allows a delegation nested in a conditional, which has no place for the macro" do
    assert_no_offense <<~RUBY
      class Foo
        attr_reader :items

        if RUBY_VERSION > "3"
          def each(&block)
            items.each(&block)
          end
        end
      end
    RUBY
  end

  test "allows a protected delegation, which the macro cannot declare" do
    assert_no_offense <<~RUBY
      class Charge
        protected
          def subunit_factor
            Currency.subunit_factor(currency)
          end
      end
    RUBY
  end

  test "allows a method with more than one statement" do
    assert_no_offense <<~RUBY
      class Charge
        private
          def subunit_factor
            log_lookup
            Currency.subunit_factor(currency)
          end
      end
    RUBY
  end

  test "autocorrects a private delegation to a constant" do
    assert_correction \
      <<~RUBY,
        class Charge
          private
            def subunit_factor(currency)
              Currency.subunit_factor(currency)
            end
        end
      RUBY
      <<~RUBY
        class Charge
          private
            delegate :subunit_factor, to: Currency, private: true
        end
      RUBY
  end

  test "folds into an existing constant-target delegate" do
    assert_correction \
      <<~RUBY,
        class Charge
          private
            delegate :unit, to: Currency, private: true

            def subunit_factor(currency)
              Currency.subunit_factor(currency)
            end
        end
      RUBY
      <<~RUBY
        class Charge
          private
            delegate :unit, :subunit_factor, to: Currency, private: true
        end
      RUBY
  end

  test "does not autocorrect a wrapper binding its own state" do
    source = <<~RUBY
      class Charge
        private
          delegate :unit, to: Currency, private: true

          def subunit_factor
            Currency.subunit_factor(options[:currency])
          end
      end
    RUBY

    assert_no_correction source
  end

  test "autocorrects a lone private delegation to the macro" do
    assert_correction \
      <<~RUBY,
        class Foo
          private
            def size
              node.size
            end
        end
      RUBY
      <<~RUBY
        class Foo
          private
            delegate :size, to: :node, private: true
        end
      RUBY
  end

  test "folds into an existing same-receiver delegate" do
    assert_correction \
      <<~RUBY,
        class Foo
          private
            attr_reader :node
            delegate :name, to: :node, private: true

            def size
              node.size
            end
        end
      RUBY
      <<~RUBY
        class Foo
          private
            attr_reader :node
            delegate :name, :size, to: :node, private: true
        end
      RUBY
  end

  test "writes a separate delegate when the existing one has a prefix" do
    assert_correction \
      <<~RUBY,
        class Foo
          private
            delegate :name, to: :node, prefix: true, private: true

            def size
              node.size
            end
        end
      RUBY
      <<~RUBY
        class Foo
          private
            delegate :name, to: :node, prefix: true, private: true
            delegate :size, to: :node, private: true
        end
      RUBY
  end

  test "writes a separate delegate when the existing one allows nil" do
    assert_correction \
      <<~RUBY,
        class Foo
          private
            delegate :name, to: :node, allow_nil: true, private: true

            def size
              node.size
            end
        end
      RUBY
      <<~RUBY
        class Foo
          private
            delegate :name, to: :node, allow_nil: true, private: true
            delegate :size, to: :node, private: true
        end
      RUBY
  end

  test "writes a separate delegate when the existing one's visibility is dynamic" do
    assert_correction \
      <<~RUBY,
        class Foo
          private
            delegate :name, to: :node, private: private_delegates?

            def size
              node.size
            end
        end
      RUBY
      <<~RUBY
        class Foo
          private
            delegate :name, to: :node, private: private_delegates?
            delegate :size, to: :node, private: true
        end
      RUBY
  end

  test "writes a new delegate beside existing declarations" do
    assert_correction \
      <<~RUBY,
        class Foo
          private
            attr_reader :node

            def size
              node.size
            end
        end
      RUBY
      <<~RUBY
        class Foo
          private
            attr_reader :node
            delegate :size, to: :node, private: true
        end
      RUBY
  end

  test "removes a same-line method without deleting the statement beside it" do
    assert_correction <<~RUBY, <<~CORRECTED
      class Foo
        private
          attr_reader :node

          def size = node.size; register_size
      end
    RUBY
      class Foo
        private
          attr_reader :node
          delegate :size, to: :node, private: true

          register_size
      end
    CORRECTED
  end

  test "allows a method with an empty body" do
    assert_no_offense <<~RUBY
      class Report
        def title
        end
      end
    RUBY
  end

  test "allows a forwarding method written at the top level" do
    assert_no_offense <<~RUBY
      def title
        document.title
      end
    RUBY
  end
end
