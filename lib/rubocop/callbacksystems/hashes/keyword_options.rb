# Keyword options resolved in Ruby's evaluation order: the last explicit pair wins unless a later splat can replace it.
class RuboCop::Callbacksystems::Hashes::KeywordOptions
  attr_reader :elements

  def initialize(*hashes)
    @elements = hashes.compact.flat_map(&:children)
  end

  def known?(key)
    option_for(key).present? || elements.none? { unknown_option?(it) }
  end

  def option_for(key)
    explicit = explicit_options_for(key).last

    explicit unless unknown_option_follows?(explicit)
  end

  def explicit_options_for(key)
    elements.select { it.pair_type? && it.key.sym_type? && it.key.value == key }
  end

  private
    def unknown_option_follows?(option)
      option && elements.drop(index_of(option) + 1).any? { unknown_option?(it) }
    end

    def index_of(option)
      elements.index { it.equal?(option) }
    end

    # A non-literal key can evaluate to the option being queried just as a keyword splat can. Literal non-symbol keys
    # cannot replace it, but abstaining for those uncommon calls keeps this reader sound without evaluating Ruby.
    def unknown_option?(element)
      element.kwsplat_type? || (element.pair_type? && !element.key.sym_type?)
    end
end
