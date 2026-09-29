require "prism"

# A correction run on a corrector of its own, so what it would do to the source can be read before it is offered.
class RuboCop::Callbacksystems::Autocorrection::Rehearsal
  delegate :empty?, :as_replacements, to: :corrector

  def initialize(correction, processed_source)
    @correction = correction
    @processed_source = processed_source
  end

  def parses?
    prism_parser? ? parsed_rewrite.success? : processed_rewrite.valid_syntax?
  end

  def keeps_comments?
    comment_counts.all? { |text, count| rewritten_comment_counts.fetch(text, 0) >= count }
  end

  private
    attr_reader :correction, :processed_source

    def prism_parser?
      processed_source.parser_engine == :parser_prism
    end

    def parsed_rewrite
      @parsed_rewrite ||= Prism.parse \
        rewritten,
        filepath: processed_source.path,
        version: processed_source.ruby_version.to_s
    end

    def rewritten
      @rewritten ||= corrector.rewrite
    end

    def corrector
      @corrector ||= RuboCop::Cop::Corrector.new(processed_source).tap { correction.call(it) }
    end

    def processed_rewrite
      @processed_rewrite ||= RuboCop::ProcessedSource.new \
        rewritten,
        processed_source.ruby_version,
        processed_source.path,
        parser_engine: processed_source.parser_engine
    end

    def comment_counts
      @comment_counts ||= processed_source.comments.map(&:text).tally
    end

    def rewritten_comment_counts
      @rewritten_comment_counts ||= rewritten_comment_texts.tally
    end

    def rewritten_comment_texts
      if prism_parser?
        parsed_rewrite.comments.map { it.location.slice }
      else
        processed_rewrite.comments.map(&:text)
      end
    end
end
