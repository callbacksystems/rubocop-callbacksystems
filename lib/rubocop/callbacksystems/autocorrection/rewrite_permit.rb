# The single rewrite a pass may spend. A statement carrying a body travels with everything written inside it, so a
# second rewrite reaching into that same text would clobber it, and the pass that follows takes the next one.
class RuboCop::Callbacksystems::Autocorrection::RewritePermit
  def initialize(granted: true)
    @granted = granted
  end

  def claim
    granted.tap { @granted = false }
  end

  private
    attr_reader :granted
end
