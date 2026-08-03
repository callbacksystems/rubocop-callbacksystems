# Runs every autocorrecting cop over the shapes its own tests declare, with a
# comment inserted before each line in turn, and reports the ones whose fixer
# drops the comment or leaves the source unparseable. Each cop's suite proves
# the fix it means to make; this proves it takes nothing else with it.
class FixerAudit
  MARKER = "# fixer-safety-marker"
  DEFAULT_FILE = "test/example_test.rb"
  HEREDOC_TAGS = %w[RUBY CORRECTED SOURCE EXPECTED].freeze
  COP_TEST_DIR = File.expand_path("../rubocop/cop/callbacksystems", __dir__)

  # Removing comments is what these are for, so losing one is the fix working.
  COMMENT_REMOVERS = %w[
    Callbacksystems/NoCommentsInTestClassBody
    Callbacksystems/NoSectionDividerComments
  ].freeze

  EM_DASH = 0x2014.chr(Encoding::UTF_8)

  # Cops whose tests build their sources some way other than a heredoc.
  EXTRA_PROBES = { "Callbacksystems/NoTypographicClutter" => "# name#{EM_DASH}required\nx = 1\n" }.freeze

  def failure_report
    failures.join("\n\n")
  end

  def failures
    @failures ||= probes.flat_map(&:failures)
  end

  def unprobed
    correcting_cops.map { it.badge.to_s } - probes.map(&:badge).uniq
  end

  # The shapes themselves, for an audit that corrects them with the whole cop set
  # rather than one cop at a time.
  def probe_sources
    probes.map { ClashAudit::Source.new(code: it.source, file: it.file) }.uniq
  end

  private
    def probes
      @probes ||= extra_probes + corpus_probes
    end

    def extra_probes
      EXTRA_PROBES.map { |badge, source| Probe.new(cop_for(badge), source, DEFAULT_FILE) }
    end

    def cop_for(badge)
      correcting_cops.find { it.badge.to_s == badge }
    end

    def correcting_cops
      @correcting_cops ||= CorrectingCops.new.classes
    end

    def corpus_probes
      Dir["#{COP_TEST_DIR}/*_test.rb"].flat_map { CopTestFile.new(it).probes }
    end

    # The cops of this gem that carry a corrector.
    class CorrectingCops
      def classes
        RuboCop::Cop::Registry.global.cops.select { own_corrector?(it) }
      end

      private
        def own_corrector?(cop_class)
          cop_class.support_autocorrect? && cop_class.badge.to_s.start_with?("Callbacksystems/")
        end
    end

    # One source a cop claims to handle, checked against the comment it must not
    # eat and the syntax it must not break.
    class Probe
      attr_reader :cop_class, :source, :file

      def initialize(cop_class, source, file)
        @cop_class = cop_class
        @source = source
        @file = file
      end

      # A source the cop leaves alone has no correction to go wrong, so only the
      # ones it rewrites are worth the variants.
      def failures
        probeable? ? variants.filter_map(&:failure) : []
      end

      def badge
        cop_class.badge.to_s
      end

      private
        def probeable?
          untouched.parses? && untouched.corrects?
        end

        def untouched
          Variant.new(self, source)
        end

        def variants
          source.lines.each_index.map { Variant.new(self, variant_at(it)) }
        end

        def variant_at(index)
          lines = source.lines
          (lines[0...index] + [ marker_line(lines[index]) ] + lines[index..]).join
        end

        def marker_line(line)
          "#{line[/\A */]}#{MARKER}\n"
        end
    end

    # One source put through a cop's fixer, and what came back.
    class Variant
      def initialize(probe, code)
        @probe = probe
        @code = code
      end

      def failure
        Failure.new(probe.badge, code, corrected) unless survives?
      rescue => error
        Failure.new(probe.badge, code, error.message.lines.first.to_s.strip)
      end

      def parses?
        processed_source.valid_syntax?
      end

      def corrects?
        corrected != code
      end

      private
        attr_reader :probe, :code

        def survives?
          rewritten.parses? && keeps_marker?
        end

        def rewritten
          self.class.new(probe, corrected)
        end

        def corrected
          @corrected ||= RuboCop::Cop::Corrector.new(processed_source).then do |corrector|
            offenses.each { corrector.merge!(it.corrector) if it.corrector }
            corrector.rewrite
          end
        end

        def processed_source
          @processed_source ||= RuboCop::ProcessedSource.new(code, RUBY_VERSION.to_f, probe.file)
        end

        def offenses
          RuboCop::Cop::Commissioner.new([ probe.cop_class.new(CopTestCase.default_config) ], [], raise_error: true)
            .investigate(processed_source).offenses
        end

        def keeps_marker?
          COMMENT_REMOVERS.include?(probe.badge) || !reads_as_comment? || corrected.include?(MARKER)
        end

        # A marker that landed inside a heredoc body is content of that string,
        # not a comment, and a fixer deleting the statement holding it is doing
        # its job. Only a marker the parser reads as a comment has to survive.
        def reads_as_comment?
          processed_source.comments.any? { it.text.include?(MARKER) }
        end
    end

    class Failure
      def initialize(badge, input, output)
        @badge = badge
        @input = input
        @output = output
      end

      def to_s
        "#{badge}\n--- given ---\n#{input}--- produced ---\n#{output}"
      end

      private
        attr_reader :badge, :input, :output
    end

    # One cop's test file, read for the heredocs it uses as examples. The suite is
    # the best record of the shapes each fixer claims to handle.
    class CopTestFile
      def initialize(path)
        @path = path
      end

      def probes
        cop_class ? bodies.map { Probe.new(cop_class, it, file) } : []
      end

      private
        attr_reader :path

        # Resolved through the registry rather than the constant, so a test file
        # naming a cop that no longer exists is skipped instead of raising.
        def cop_class
          @cop_class ||= RuboCop::Cop::Registry.global.cops.find { it.name == declared_cop_name }
        end

        def declared_cop_name
          @declared_cop_name ||= lines.find { it.include?("self.cop_class = ") }
            &.split("self.cop_class = ")&.last&.strip
        end

        def lines
          @lines ||= File.readlines(path, chomp: true)
        end

        def bodies
          scanned_from(0, [])
        end

        def scanned_from(index, collected)
          return collected if index >= lines.size

          after, bodies = consumed(index + 1, tags_at(index), [])
          scanned_from(after, collected | bodies)
        end

        def consumed(index, tags, collected)
          return [ index, collected ] if tags.empty?

          stop = closing_line_of(tags.first, index)
          consumed(stop + 1, tags.drop(1), collected + [ dedented(lines[index...stop]) ])
        end

        def closing_line_of(tag, start)
          (start...lines.size).find { lines[it].strip == tag } || lines.size
        end

        def dedented(body)
          indent = body.reject { it.strip.empty? }.map { it[/\A */].size }.min || 0
          "#{body.map { it[indent..] || "" }.join("\n")}\n"
        end

        def tags_at(index)
          HEREDOC_TAGS & lines[index].scan(/<<~(\w+)/).flatten
        end

        # A cop scoped to app/ or test/ reports nothing under another path, so use
        # whichever one its own tests use.
        def file
          @file ||= lines.find { it =~ /file: "[^"]+"/ }&.[](/file: "([^"]+)"/, 1) || DEFAULT_FILE
        end
    end
end
