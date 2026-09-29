require "test_helper"

class RuboCop::Cop::Callbacksystems::NoConsecutiveAppendsTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoConsecutiveAppends

  test "registers offense for two appends with <<" do
    assert_offense <<~RUBY
      list = []
      list << header
      list << body
    RUBY
  end

  test "registers offense for three appends mixing << and push" do
    assert_offense <<~RUBY
      list = []
      list << header
      list.push(body, signature)
      list << footer
    RUBY
  end

  test "allows appends to an instance variable whose value is unknown" do
    assert_no_offense <<~RUBY
      @list << header
      @list << body
    RUBY
  end

  test "allows appends to a parameter whose value is unknown" do
    assert_no_offense <<~RUBY
      def build(list)
        list << header
        list << body
      end
    RUBY
  end

  test "does not take a conditional Array assignment as proof about a parameter" do
    assert_no_offense <<~RUBY
      def build(list, reset:)
        list = [] if reset
        list << header
        list << body
      end
    RUBY
  end

  test "allows appends to a local assigned an unknown value" do
    assert_no_offense <<~RUBY
      def build
        list = custom_collection
        list << header
        list << body
      end
    RUBY
  end

  test "registers offense for appends to an Array constructor" do
    assert_offense <<~RUBY
      list = Array.new
      list << header
      list << body
    RUBY
  end

  test "allows appends to an unknown bare method result" do
    assert_no_offense <<~RUBY
      def build
        lines << header
        lines << body
      end
    RUBY
  end

  test "registers offense for appends to a bare method backed by an array" do
    assert_offense <<~RUBY
      class Report
        def initialize
          @lines = []
        end

        def build
          lines << header
          lines << body
        end
      end
    RUBY
  end

  test "does not use an instance variable from another class as evidence for a bare method result" do
    assert_no_offense <<~RUBY
      class First
        def initialize
          @lines = []
        end
      end

      class Second
        def build
          lines << header
          lines << body
        end
      end
    RUBY
  end

  test "does not combine instance and singleton storage as evidence for a bare method result" do
    assert_no_offense <<~RUBY
      class Report
        @lines = []

        def build
          lines << header
          lines << body
        end
      end
    RUBY
  end

  test "does not let a nested class assignment obscure appends to the outer instance" do
    assert_correction <<~RUBY, <<~CORRECTED
      class Report
        def initialize
          @lines = []
        end

        def build
          Class.new { @lines = +"" }
          @lines << header
          @lines << body
        end
      end
    RUBY
      class Report
        def initialize
          @lines = []
        end

        def build
          Class.new { @lines = +"" }
          @lines.push(header, body)
        end
      end
    CORRECTED
  end

  test "does not let another receiver's assignment obscure appends to the outer instance" do
    assert_offense <<~RUBY
      class Report
        def initialize
          @lines = []
        end

        def build(target)
          target.instance_eval { @lines = +"" }
          @lines << header
          @lines << body
        end
      end
    RUBY
  end

  test "still treats current-self and ordinary block assignments as instance state" do
    [ "self.instance_eval", "items.each" ].each do |invocation|
      assert_no_offense <<~RUBY
        class Report
          def initialize
            @lines = []
          end

          def build
            #{invocation} { @lines = +"" }
            @lines << header
            @lines << body
          end
        end
      RUBY
    end
  end

  test "registers offense for appends to a local beside another local" do
    assert_offense <<~RUBY
      def build
        lines = []
        text = +""
        lines << text
        lines << body
      end
    RUBY
  end

  test "registers offense for each run in one statement list" do
    assert_offense <<~RUBY, count: 2
      lines = []
      footers = []
      lines << header
      lines << body
      footers << signature
      footers << date
    RUBY
  end

  test "allows appends to different receivers" do
    assert_no_offense <<~RUBY
      list << header
      other << body
    RUBY
  end

  test "allows appends with a statement in between" do
    assert_no_offense <<~RUBY
      list << header
      prepare
      list << body
    RUBY
  end

  test "allows a single append" do
    assert_no_offense <<~RUBY
      list << header
      list.size
    RUBY
  end

  test "allows an append whose value reads the receiver" do
    assert_no_offense <<~RUBY
      list << header
      list << list.size
    RUBY
  end

  test "allows appends whose value reassigns the local receiver" do
    assert_no_offense <<~RUBY
      list = []
      list << (list = replacement)
      list << body
    RUBY
  end

  test "allows appends whose value binds the local receiver through a pattern" do
    assert_no_offense <<~RUBY
      list = []
      list << (value => list)
      list << body
    RUBY
  end

  test "allows appends whose value binds the local receiver in a case pattern" do
    assert_no_offense <<~RUBY
      list = []
      list << (case value
               in { list: } then list
               end)
      list << body
    RUBY
  end

  test "allows appends whose value reassigns the local receiver through compound or multiple assignment" do
    [ "list += replacement", "list, other = replacement" ].each do |assignment|
      assert_no_offense <<~RUBY
        list = []
        list << (#{assignment})
        list << body
      RUBY
    end
  end

  test "allows appends whose value reassigns the instance-variable receiver" do
    assert_no_offense <<~RUBY
      @list = []
      @list << (@list = replacement)
      @list << body
    RUBY
  end

  test "collapses appends when a nested block shadows the receiver name" do
    assert_correction <<~RUBY, <<~CORRECTED
      list = []
      list << items.map { |list| list.name }
      list << body
    RUBY
      list = []
      list.push(items.map { |list| list.name }, body)
    CORRECTED
  end

  test "allows appends to a method call with arguments" do
    assert_no_offense <<~RUBY
      lines(1) << header
      lines(1) << body
    RUBY
  end

  test "allows a push with a block pass" do
    assert_no_offense <<~RUBY
      list.push(&header)
      list.push(&body)
    RUBY
  end

  test "allows appends to a local assigned a string" do
    assert_no_offense <<~RUBY
      def build
        text = +""
        text << header
        text << body
      end
    RUBY
  end

  test "allows appends to a local assigned a set" do
    assert_no_offense <<~RUBY
      def build
        names = Set.new
        names << first
        names << second
      end
    RUBY
  end

  test "allows appends to a local rebound by pattern matching" do
    assert_no_offense <<~RUBY
      def build(input)
        list = []
        input => { list: }
        list << first
        list << second
      end
    RUBY
  end

  test "allows appends to an instance variable memoized as a string" do
    assert_no_offense <<~RUBY
      class Report
        def build
          @text << header
          @text << body
        end

        def text
          @text ||= String.new
        end
      end
    RUBY
  end

  test "allows appends to a bare method call backed by a set" do
    assert_no_offense <<~RUBY
      class Roster
        def initialize
          @names = names.to_set
        end

        def add
          names << first
          names << second
        end
      end
    RUBY
  end

  test "collapses two appends with << into one push" do
    assert_correction <<~RUBY, <<~CORRECTED
      list = []
      list << header
      list << body
    RUBY
      list = []
      list.push(header, body)
    CORRECTED
  end

  test "collapses three appends mixing << and push into one push" do
    assert_correction <<~RUBY, <<~CORRECTED
      list = []
      list << header
      list.push(body, signature)
      list << footer
    RUBY
      list = []
      list.push(header, body, signature, footer)
    CORRECTED
  end

  test "does not correct a known bare method receiver whose evaluation count would change" do
    code = <<~RUBY
      class Report
        def initialize
          @lines = []
        end

        def build
          lines << header
          lines << body
          lines.join
        end
      end
    RUBY

    assert_uncorrectable_offense code
  end

  test "keeps a comment above the run" do
    assert_correction <<~RUBY, <<~CORRECTED
      # the letter
      list = []
      list << header
      list << body
    RUBY
      # the letter
      list = []
      list.push(header, body)
    CORRECTED
  end

  test "does not correct a run carrying a comment" do
    code = <<~RUBY
      list << header # first
      list << body
    RUBY

    assert_correction code, code
  end

  test "does not correct a run with a comment between its statements" do
    code = <<~RUBY
      list << header
      # then the rest
      list << body
    RUBY

    assert_correction code, code
  end

  test "does not correct a run carrying a heredoc" do
    code = <<~RUBY
      list << <<~TEXT
        Hello
      TEXT
      list << body
    RUBY

    assert_correction code, code
  end
end
