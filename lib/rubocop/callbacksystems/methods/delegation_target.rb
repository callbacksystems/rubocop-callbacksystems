# The receiver of a hand-written delegation, read as the target a `delegate` macro would name. A constant stands for
# itself (`to: Currency`), a call on self becomes a symbol (`to: :registry`), and a chain of them becomes a dotted
# string (`to: "config.postgres"`). Anything else in the chain gives up the whole reading.
class RuboCop::Callbacksystems::Methods::DelegationTarget
  def initialize(receiver)
    @receiver = receiver
  end

  def delegable?
    constant? || chain_names.any?
  end

  def source
    constant? ? name : quoted_name
  end

  def name
    constant? ? receiver.source : chain_names.join(".")
  end

  def nested?
    chain_names.many?
  end

  private
    attr_reader :receiver

    def constant?
      receiver&.const_type? || false
    end

    def chain_names
      @chain_names ||= names_in(receiver) || []
    end

    def names_in(node)
      names = []
      current = node

      while chained_call?(current)
        names << current.method_name
        current = current.receiver
      end

      names.reverse if current.nil? || current.self_type?
    end

    def chained_call?(node)
      node&.send_type? && node.arguments.empty?
    end

    def quoted_name
      nested? ? "\"#{name}\"" : ":#{name}"
    end
end
