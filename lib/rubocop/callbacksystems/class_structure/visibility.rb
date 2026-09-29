# The visibility established by one class body, indexed once for every reader of that body. Section modifiers apply to
# the statements below them, while named modifiers are kept separately because they reach definitions above them.
class RuboCop::Callbacksystems::ClassStructure::Visibility
  include RuboCop::Callbacksystems::Helpers

  Assignment = Data.define(:kind, :name, :position, :level)

  class << self
    def for(body)
      body ? CACHE_LOCK.synchronize { CACHE[body] ||= new(body) } : new(nil)
    end

    private
      CACHE = ObjectSpace::WeakMap.new
      CACHE_LOCK = Mutex.new
  end

  def initialize(body)
    @body = body
  end

  def each_statement
    if block_given?
      statements.each_with_index { |statement, index| yield statement, transitions[index] }
    else
      to_enum(__method__)
    end
  end

  def level_at(node)
    statement_index_at(node)&.then { transitions[it] } || transitions.last
  end

  def assignment_after(node, singleton:)
    assignments.fetch([ singleton ? :singleton : :instance, node.method_name ], []).last&.then do |assignment|
      assignment if assignment.position >= node.source_range.end_pos
    end
  end

  private
    NAMED_LEVELS = {
      public: [ :instance, :public ],
      protected: [ :instance, :protected ],
      private: [ :instance, :private ],
      public_class_method: [ :singleton, :public ],
      private_class_method: [ :singleton, :private ]
    }

    attr_reader :body

    def statements
      @statements ||= statements_in(body)
    end

    def transitions
      @transitions ||= statements.each_with_object([ :public ]) do |statement, levels|
        levels << (visibility_modifier_of(statement) || levels.last)
      end
    end

    def statement_index_at(node)
      statement_end_positions.bsearch_index { it > node.source_range.begin_pos }
    end

    def statement_end_positions
      @statement_end_positions ||= statements.map { it.source_range.end_pos }
    end

    def assignments
      @assignments ||= statements.flat_map { assignments_from(it) }.group_by { [ it.kind, it.name ] }
    end

    def assignments_from(statement)
      named_level_of(statement)&.then do |kind, level|
        name_arguments_of(statement).map do |name|
          Assignment.new(kind:, name: name.value.to_sym, position: statement.source_range.begin_pos, level:)
        end
      end || []
    end

    def named_level_of(statement)
      NAMED_LEVELS[statement.method_name] if bare_send?(statement)
    end
end
