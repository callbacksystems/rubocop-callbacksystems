require "test_helper"

class AutocorrectIntegrationTest < ActiveSupport::TestCase
  include TemporaryProject

  setup do
    create_file ".rubocop.yml", <<~YAML
      plugins:
        - rubocop-callbacksystems

      AllCops:
        NewCops: enable
        SuggestExtensions: false
    YAML
    @source = create_file "example.rb", <<~RUBY
      class Example
        attr_reader :record
        def name; end
        private
          delegate :title, to: :record
      end
      class Marker; end
    RUBY
  end

  test "safe mode corrects only safe cops" do
    _output, error, _status = autocorrect(@source, "-a")

    assert_empty error
    assert_equal safely_corrected_source, File.binread(@source)
  end

  test "all mode corrects safe and unsafe cops together" do
    output, error, status = autocorrect(@source, "-A")

    assert_predicate status, :success?, "#{output}\n#{error}"
    assert_equal fully_corrected_source, File.binread(@source)
  end

  test "all mode reaches a fixed point" do
    first_output, first_error, first_status = autocorrect(@source, "-A")
    corrected = File.binread(@source)
    second_output, second_error, second_status = autocorrect(@source, "-A")

    assert_predicate first_status, :success?, "#{first_output}\n#{first_error}"
    assert_predicate second_status, :success?, "#{second_output}\n#{second_error}"
    assert_equal corrected, File.binread(@source)
  end

  test "a correction does not leave project-index diagnostics one run behind" do
    source = create_file "lib/container.rb", <<~RUBY
      class Container
        VALUE = 1
        def process
          Worker.new.run
          nil
        end

        private
          class Worker
            def run
            end

            private
              def unused
              end
          end
      end
    RUBY

    output, error, _status = rubocop.run \
      "--config", project.path_of(".rubocop.yml"),
      "--only", project_index_cops,
      "--cache", "false",
      "-a",
      source

    assert_empty error
    second_output, second_error, _second_status = rubocop.run \
      "--config", project.path_of(".rubocop.yml"),
      "--only", project_index_cops,
      "--cache", "false",
      source

    assert_empty second_error
    assert_includes second_output, "Callbacksystems/UnusedPrivateMethodInNestedClass"
    assert_includes output, "Callbacksystems/UnusedPrivateMethodInNestedClass"
  end

  private
    def autocorrect(source, mode)
      rubocop.run \
        "--config", project.path_of(".rubocop.yml"),
        "--only", correcting_cops,
        "--cache", "false",
        mode,
        source
    end

    def rubocop
      @rubocop ||= RuboCopCommand.new(project)
    end

    def correcting_cops
      %w[
        Callbacksystems/DelegateRequiresPrivateOption
        Callbacksystems/EmptyLineBeforeMethod
        Callbacksystems/ExpandedEmptyClassOrModule
      ].join(",")
    end

    def safely_corrected_source
      <<~RUBY
        class Example
          attr_reader :record

          def name; end
          private
            delegate :title, to: :record
        end
        class Marker
        end
      RUBY
    end

    def fully_corrected_source
      <<~RUBY
        class Example
          attr_reader :record

          def name; end
          private
            delegate :title, to: :record, private: true
        end
        class Marker
        end
      RUBY
    end

    def project_index_cops
      %w[
        Callbacksystems/EmptyLineBeforeMethod
        Callbacksystems/UnusedPrivateMethodInNestedClass
      ].join(",")
    end
end
