class RuboCop::Callbacksystems::Offense
  attr_reader :range, :message, :correction

  def initialize(range, message, correcting: true, &correction)
    @range = range
    @message = message
    @correction = correcting ? correction : nil
  end

  def correct(corrector)
    correction&.call(corrector)
  end
end
