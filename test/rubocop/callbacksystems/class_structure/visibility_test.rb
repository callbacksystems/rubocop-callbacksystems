require "test_helper"

class RuboCop::Callbacksystems::ClassStructure::VisibilityTest < ActiveSupport::TestCase
  include SourceParsing

  test "for shares the index built for one body" do
    body = body_of("class User\n  def name; end\nend\n")

    assert_same visibility_of(body), visibility_of(body)
  end

  test "for builds a public empty index without a body" do
    visibility = visibility_of(nil)
    node = processed_source("work").ast

    assert_equal :public, visibility.level_at(node)
    assert_nil visibility.assignment_after(node, singleton: false)
  end

  test "each_statement yields the visibility in force before each statement" do
    body = body_of(<<~RUBY)
      class User
        def name; end
        private
          def token; end
      end
    RUBY

    assert_equal %i[ public public private ], visibility_of(body).each_statement.map { |_node, level| level }
  end

  test "level_at reads the section containing a node nested inside a statement" do
    body = body_of(<<~RUBY)
      class User
        private
          OPTIONS = { token: TOKEN }
      end
    RUBY
    token = body.each_descendant(:const).find { it.short_name == :TOKEN }

    assert_equal :private, visibility_of(body).level_at(token)
  end

  test "assignment_after finds the last named instance visibility applied later" do
    body = body_of(<<~RUBY)
      class User
        def token; end
        private :token
        public :token
      end
    RUBY
    method = body.each_descendant(:def).first

    assert_equal :public, visibility_of(body).assignment_after(method, singleton: false).level
  end

  test "assignment_after ignores a named visibility applied before the definition" do
    body = body_of(<<~RUBY)
      class User
        private :token
        def token; end
      end
    RUBY
    method = body.each_descendant(:def).first

    assert_nil visibility_of(body).assignment_after(method, singleton: false)
  end

  test "assignment_after keeps singleton visibility separate from instance visibility" do
    body = body_of(<<~RUBY)
      class User
        def self.find; end
        private :find
        private_class_method :find
      end
    RUBY
    method = body.each_descendant(:defs).first

    assert_equal :private, visibility_of(body).assignment_after(method, singleton: true).level
  end

  private
    def body_of(source)
      processed_source(source).ast.body
    end

    def visibility_of(body)
      RuboCop::Callbacksystems::ClassStructure::Visibility.for(body)
    end
end
