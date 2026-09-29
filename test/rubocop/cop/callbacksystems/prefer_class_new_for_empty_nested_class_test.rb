require "test_helper"

class RuboCop::Cop::Callbacksystems::PreferClassNewForEmptyNestedClassTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PreferClassNewForEmptyNestedClass
  self.project_indexed = true

  TAB = "\t"

  test "registers offense for an empty nested class on one line" do
    offenses = assert_offense <<~RUBY
      class Configuration
        class Error < StandardError; end

        def call
        end
      end
    RUBY

    assert_includes offenses.first.message, "Error"
    assert_includes offenses.first.message, "Class.new"
  end

  test "registers offense for an empty nested class over two lines" do
    assert_offense <<~RUBY
      class Configuration
        class Error < StandardError
        end
      end
    RUBY
  end

  test "registers offense for an empty nested class without a superclass" do
    assert_offense <<~RUBY
      class Configuration
        class Marker; end
      end
    RUBY
  end

  test "registers offense inside a module" do
    assert_offense <<~RUBY
      module PgBox
        class Error < StandardError; end
      end
    RUBY
  end

  test "reports without a project index but leaves the correction for a human" do
    assert_uncorrectable_offense <<~RUBY, project_sources: false
      class Configuration
        class Marker; end
      end
    RUBY
  end

  test "allows a nested class with a body" do
    assert_no_offense <<~RUBY
      class Configuration
        class Error < StandardError
          def message
            "boom"
          end
        end
      end
    RUBY
  end

  test "allows an empty class at the top level" do
    assert_no_offense <<~RUBY
      class PgBox::ConfigurationError < StandardError; end
    RUBY
  end

  test "allows a constant already declaring the class" do
    assert_no_offense <<~RUBY
      class Configuration
        Error = Class.new(StandardError)
      end
    RUBY
  end

  test "autocorrects to a constant carrying the superclass" do
    assert_correction \
      <<~RUBY,
        class Configuration
          class Error < StandardError; end

          def call
          end
        end
      RUBY
      <<~RUBY
        class Configuration
          Error = Class.new(StandardError)

          def call
          end
        end
      RUBY
  end

  test "autocorrects the two-line form" do
    assert_correction \
      <<~RUBY,
        class Configuration
          class Marker
          end
        end
      RUBY
      <<~RUBY
        class Configuration
          Marker = Class.new
        end
    RUBY
  end

  test "autocorrects without losing comments on the opening and closing lines" do
    assert_correction \
      <<~RUBY,
        class Configuration
          class Marker # opening
          end # closing
        end
      RUBY
      <<~RUBY
        class Configuration
          Marker = Class.new # opening
          # closing
        end
      RUBY
  end

  test "keeps tab indentation when comments need new lines" do
    assert_correction \
      "class Configuration\n#{TAB}class Marker # opening\n#{TAB}end # closing\nend\n",
      "class Configuration\n#{TAB}Marker = Class.new # opening\n#{TAB}# closing\nend\n"
  end

  test "corrects a nested class that follows other code on its line" do
    assert_correction \
      "class Configuration; class Marker; end; end\n",
      "class Configuration; Marker = Class.new; end\n"
  end

  test "corrects a nested class that follows multibyte source on its line" do
    assert_correction \
      "class Configuration; \"é\"; class Marker; end; ready; end\n",
      "class Configuration; \"é\"; Marker = Class.new; ready; end\n"
  end

  test "keeps comments in their source order around the declaration" do
    assert_correction \
      <<~RUBY,
        class Configuration
          class Marker
            # why it exists
          end # Marker
        end
      RUBY
      <<~RUBY
        class Configuration
          # why it exists
          Marker = Class.new # Marker
        end
      RUBY
  end

  test "does not take a same-line sibling's trailing comment or delete the sibling" do
    assert_correction <<~RUBY, <<~CORRECTED
      class Configuration
        class Marker; end; register # register the marker
      end
    RUBY
      class Configuration
        Marker = Class.new; register # register the marker
      end
    CORRECTED
  end

  test "does not take the containing class's closing comment on a shared line" do
    assert_correction <<~RUBY, <<~CORRECTED
      class Configuration
        class Marker; end; end # Configuration
    RUBY
      class Configuration
        Marker = Class.new; end # Configuration
    CORRECTED
  end

  test "keeps a comment embedded in the superclass expression exactly once" do
    assert_correction <<~RUBY, <<~CORRECTED
      class Configuration
        class Error < ::
          # The portable base.
          StandardError
        end
      end
    RUBY
      class Configuration
        Error = Class.new(::
          # The portable base.
          StandardError)
      end
    CORRECTED
  end

  test "leaves a definition carrying a tooling comment for a human" do
    assert_uncorrectable_offense <<~RUBY
      class Configuration
        class Marker # :nodoc:
        end
      end
    RUBY
  end

  test "leaves a superclass expression carrying a heredoc for a human" do
    assert_uncorrectable_offense <<~RUBY
      class Configuration
        class Error < resolve(<<~NAME)
          error
        NAME
        end
      end
    RUBY
  end

  test "leaves a nested class whose value is assigned for a human" do
    assert_uncorrectable_offense <<~RUBY
      RESULT = class Configuration
        class Marker
        end
      end
    RUBY
  end

  test "still corrects when a following statement discards the nested class value" do
    assert_correction <<~RUBY, <<~CORRECTED
      RESULT = class Configuration
        class Marker
        end
        ready
      end
    RUBY
      RESULT = class Configuration
        Marker = Class.new
        ready
      end
    CORRECTED
  end

  test "corrects a declaration followed by a reopening in the same file" do
    assert_correction <<~RUBY, <<~CORRECTED
      class Configuration
        class Marker; end

        class Marker
          def call; end
        end
      end
    RUBY
      class Configuration
        Marker = Class.new

        class Marker
          def call; end
        end
      end
    CORRECTED
  end

  test "leaves a reopening for a human because Class.new would replace the constant" do
    assert_uncorrectable_offense <<~RUBY
      class Configuration
        Error = Class.new(StandardError)
        class Error < StandardError; end
      end
    RUBY
  end

  test "leaves a reopening from an earlier outer-class body for a human" do
    assert_uncorrectable_offense <<~RUBY
      class Configuration
        Marker = Class.new
      end

      class Configuration
        class Marker; end
      end
    RUBY
  end

  test "leaves a reopening from another file for a human" do
    assert_uncorrectable_offense \
      <<~RUBY,
        class Configuration
          class Marker; end
        end
      RUBY
      file: "app/models/configuration.rb",
      project_sources: {
        "app/models/configuration/marker.rb" => <<~RUBY
          class Configuration::Marker
            def call; end
          end
        RUBY
      }
  end

  test "leaves a reopening of an external core class for a human" do
    assert_uncorrectable_offense <<~RUBY
      class Configuration
        class ::String; end
      end
    RUBY
  end

  test "leaves a qualified non-core declaration for a human" do
    assert_uncorrectable_offense <<~RUBY
      module External
      end

      class Configuration
        class External::Marker; end
      end
    RUBY
  end

  test "leaves a declaration under an unresolved implicit namespace for a human" do
    assert_uncorrectable_offense <<~RUBY, file: "app/models/admin/configuration.rb"
      class Admin::Configuration
        class Marker; end
      end
    RUBY
  end

  test "leaves a declaration under a dynamic namespace for a human" do
    assert_uncorrectable_offense <<~RUBY
      class namespace::Configuration
        class Marker; end
      end
    RUBY
  end

  test "leaves correction alone while another indexed file has a parse error" do
    assert_uncorrectable_offense \
      <<~RUBY,
        class Configuration
          class Marker; end
        end
      RUBY
      project_sources: { "app/models/broken.rb" => "class Broken\n" }
  end

  test "leaves an autoloaded constant for a human" do
    assert_uncorrectable_offense <<~RUBY
      class Configuration
        autoload :Marker, "marker"
        class Marker; end
      end
    RUBY
  end

  test "leaves a constant installed reflectively for a human" do
    assert_uncorrectable_offense <<~RUBY
      class Configuration
        self.const_set("Marker", marker_class)
        class Marker; end
      end
    RUBY
  end

  test "leaves a dynamic reflective declaration for a human" do
    assert_uncorrectable_offense <<~RUBY
      class Configuration
        const_set(marker_name, marker_class)
        class Marker; end
      end
    RUBY
  end

  test "leaves an argumentless reflective declaration for a human" do
    assert_uncorrectable_offense <<~RUBY
      class Configuration
        const_set
        class Marker; end
      end
    RUBY
  end

  test "leaves a reflective declaration of another constant for a human" do
    assert_uncorrectable_offense <<~RUBY
      class Configuration
        autoload :Other, "other"
        class Marker; end
      end
    RUBY
  end
end
