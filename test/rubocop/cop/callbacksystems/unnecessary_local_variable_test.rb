require "test_helper"

class RuboCop::Cop::Callbacksystems::UnnecessaryLocalVariableTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::UnnecessaryLocalVariable

  test "registers offense for variable aliasing a method call" do
    assert_offense <<~RUBY
      def process
        directory = forbidden_directory
        add_offense(node) if directory
      end
    RUBY
  end

  test "registers offense for variable aliasing a method call with receiver" do
    assert_offense <<~RUBY
      def process
        memo_node = checker.memoization_node
        add_offense(memo_node)
      end
    RUBY
  end

  test "registers offense for variable aliasing a method call with arguments" do
    assert_offense <<~RUBY
      def process
        first_stmt = first_statement_in(body)
        first_stmt&.if_type?
      end
    RUBY
  end

  test "allows variable used inside a nested block" do
    assert_no_offense <<~RUBY
      def detect
        called = collect_called_methods
        items.filter_map { |item| called.include?(item) }
      end
    RUBY
  end

  test "registers offense for variable with safe navigation" do
    assert_offense <<~RUBY
      def process
        result = object&.value
        transform(result)
      end
    RUBY
  end

  test "registers offense inside a block scope" do
    assert_offense <<~RUBY
      items.each do |item|
        name = item.full_name
        puts name
      end
    RUBY
  end

  test "allows variable used multiple times" do
    assert_no_offense <<~RUBY
      def process
        user = find_user
        user.activate
        user.notify
      end
    RUBY
  end

  test "allows variable used in two contexts" do
    assert_no_offense <<~RUBY
      def process
        collapser = HashCollapser.new(node)
        add_offense(node) if collapser.collapsable?
        collapser.collapsed
      end
    RUBY
  end

  test "allows assignment in conditional" do
    assert_no_offense <<~RUBY
      def process
        if user = find_user
          user.activate
        end
      end
    RUBY
  end

  test "allows array literal initialization" do
    assert_no_offense <<~RUBY
      def process
        items = []
        items << item
      end
    RUBY
  end

  test "allows hash literal initialization" do
    assert_no_offense <<~RUBY
      def process
        options = {}
        options[:key] = value
      end
    RUBY
  end

  test "allows constructor mutated inside a loop" do
    assert_no_offense <<~RUBY
      def process
        result = Set.new
        items.each { |item| result << item }
      end
    RUBY
  end

  test "allows method call used inside a loop" do
    assert_no_offense <<~RUBY
      def detect
        called = collect_called_methods
        items.each { |item| called.include?(item) }
      end
    RUBY
  end

  test "flags constructor used outside a loop" do
    assert_offense <<~RUBY
      def process
        user = User.new(params)
        user.save!
      end
    RUBY
  end

  test "allows variable used inside deeply nested blocks" do
    assert_no_offense <<~RUBY
      def process
        config = load_config
        groups.each do |group|
          group.items.each do |item|
            item.apply(config)
          end
        end
      end
    RUBY
  end

  test "allows reassigned variable" do
    assert_no_offense <<~RUBY
      def process
        current = node.receiver
        current = current.next while current
      end
    RUBY
  end

  test "allows non-method-call assignment" do
    assert_no_offense <<~RUBY
      def process
        name = "hello"
        puts name
      end
    RUBY
  end

  test "allows variable naming an expression with an operator" do
    assert_no_offense <<~RUBY
      def validate(answer)
        invalid_values = answer.selected_values - valid_values
        answer.errors.add(:base) if invalid_values.any?
      end
    RUBY
  end

  test "allows variable naming a collection mapped with a block-pass" do
    assert_no_offense <<~RUBY
      def validate(answer)
        valid_values = options.map(&:value)
        answer.errors.add(:base) if (answer.selected_values - valid_values).any?
      end
    RUBY
  end

  test "allows variable naming a value computed from an array literal" do
    assert_no_offense <<~RUBY
      def merge(segment, other)
        new_end_time = [ segment.end_time, other.end_time ].max
        Segment.new(segment.start_time, new_end_time)
      end
    RUBY
  end

  test "allows variable naming a value computed from a hash literal" do
    assert_no_offense <<~RUBY
      def configure(options)
        settings = { locale: :en }.merge(options)
        apply(settings)
      end
    RUBY
  end

  test "allows variable aliasing a multiline call" do
    assert_no_offense <<~RUBY
      def connect
        record = relation.create! \\
          type: "Report",
          data: {}
        record.deliver
      end
    RUBY
  end

  test "allows assignment in parenthesized if condition" do
    assert_no_offense <<~RUBY
      def process
        if (user = find_user)
          user.activate
        end
      end
    RUBY
  end

  test "allows assignment in boolean expression with subsequent use" do
    assert_no_offense <<~RUBY
      def process
        items.find { |i| (matched = pattern.match(i)) && matched.captures.first }
      end
    RUBY
  end

  test "allows assignment in while loop condition" do
    assert_no_offense <<~RUBY
      def process
        while (chunk = stream.read_chunk)
          handle(chunk)
        end
      end
    RUBY
  end

  test "allows snapshot variable restored in ensure" do
    assert_no_offense <<~RUBY
      def with_context(scope)
        outer_context = context
        @context = "\#{context}/\#{scope}"
        yield
      ensure
        @context = outer_context
      end
    RUBY
  end

  test "allows snapshot variable referenced in rescue" do
    assert_no_offense <<~RUBY
      def request_with_logging
        data = build_payload
        send_request(data)
      rescue => e
        log_failure(data, e)
      end
    RUBY
  end

  test "inlines a variable read in the next statement" do
    assert_correction <<~RUBY, <<~CORRECTED
      def process
        directory = forbidden_directory
        add_offense(node) if directory
      end
    RUBY
      def process
        add_offense(node) if forbidden_directory
      end
    CORRECTED
  end

  test "inlines a method call with a receiver" do
    assert_correction <<~RUBY, <<~CORRECTED
      def process
        memo_node = checker.memoization_node
        add_offense(memo_node)
      end
    RUBY
      def process
        add_offense(checker.memoization_node)
      end
    CORRECTED
  end

  test "parenthesizes a bare call inlined into a receiver" do
    assert_correction <<~RUBY, <<~CORRECTED
      def process
        account = find_account "personal"
        account.email
      end
    RUBY
      def process
        find_account("personal").email
      end
    CORRECTED
  end

  test "parenthesizes a bare call inlined into a later argument" do
    assert_correction <<~RUBY, <<~CORRECTED
      def process
        account = find_account "personal"
        assert_equal expected, account
      end
    RUBY
      def process
        assert_equal expected, find_account("personal")
      end
    CORRECTED
  end

  test "parenthesizes a bare call with a receiver and several arguments" do
    assert_correction <<~RUBY, <<~CORRECTED
      def process
        slot = calendar.slot_at 9, duration: 30
        slot.available?
      end
    RUBY
      def process
        calendar.slot_at(9, duration: 30).available?
      end
    CORRECTED
  end

  test "leaves an already parenthesized call alone" do
    assert_correction <<~RUBY, <<~CORRECTED
      def process
        account = find_account("personal")
        account.email
      end
    RUBY
      def process
        find_account("personal").email
      end
    CORRECTED
  end

  test "leaves a variable read two statements later for a human" do
    assert_correction <<~RUBY, <<~SAME
      def process
        directory = forbidden_directory
        log_something
        add_offense(node) if directory
      end
    RUBY
      def process
        directory = forbidden_directory
        log_something
        add_offense(node) if directory
      end
    SAME
  end
end
