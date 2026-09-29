require "digest"

class RuboCop::Callbacksystems::ProjectIndex::Reading
  extend RuboCop::Callbacksystems::ProjectIndex::Cache

  INCOMPLETE_DIAGNOSTICS = %w[
    ParseError DynamicConstantReference DynamicAncestor DynamicSingletonDefinition
  ]
  OPAQUE_CONSTANT_REFLECTIONS = %w[
    const_get const_set remove_const autoload constantize safe_constantize
    eval class_eval class_exec module_eval module_exec instance_eval instance_exec
    each_object constants descendants subclasses unsafe_load unsafe_load_file
  ].to_set
  OPAQUE_DISPATCH_METHODS = %w[ send __send__ public_send method public_method ].to_set
  OPAQUE_RECEIVER_METHODS = { "Marshal" => %w[ load restore ].to_set }
  RECEIVER_SEPARATOR_WIDTHS = [ 1, 2 ]

  def initialize(project_index)
    @project_index = project_index
  end

  def checksum
    @checksum ||= DocumentsChecksum.new(project_index).to_s
  end

  def reliable?
    return @reliable if defined?(@reliable)

    @reliable = RuboCop::Callbacksystems::ProjectIndex::Coverage.complete?(project_index) &&
      !diagnostics.any_named?(*INCOMPLETE_DIAGNOSTICS) &&
      !opaque_reflection?
  end

  private
    attr_reader :project_index

    def diagnostics
      @diagnostics ||= RuboCop::Callbacksystems::ProjectIndex::Diagnostics.for(project_index)
    end

    def opaque_reflection?
      return @opaque_reflection if defined?(@opaque_reflection)

      @opaque_reflection = project_index.method_references.any? do |reference|
        method_name = reference.name.delete_suffix("()")
        OPAQUE_CONSTANT_REFLECTIONS.include?(method_name) ||
          (OPAQUE_DISPATCH_METHODS.include?(method_name) && opaque_dispatch_receiver?(reference.receiver)) ||
          opaque_receiver_method?(reference, method_name:)
      end
    end

    def opaque_dispatch_receiver?(receiver)
      receiver.nil? || receiver.is_a?(Rubydex::SingletonClass)
    end

    def opaque_receiver_method?(reference, method_name:)
      receiver_names_of(reference).any? do |receiver_name|
        OPAQUE_RECEIVER_METHODS.fetch(receiver_name) { [] }.include?(method_name)
      end
    end

    def receiver_names_of(reference)
      direct_receiver_name_of(reference).then do |name|
        name ? Set[name] : constant_receiver_names.fetch(reference_location_key(reference)) { Set.new }
      end
    end

    def direct_receiver_name_of(reference)
      receiver = reference.receiver
      receiver.attached_class.name if receiver.is_a?(Rubydex::SingletonClass)
    end

    def constant_receiver_names
      @constant_receiver_names ||= project_index.constant_references.each_with_object({}) do |reference, names|
        RECEIVER_SEPARATOR_WIDTHS.each do |separator_width|
          key = location_key(reference.location, column: reference.location.end_column + separator_width)
          (names[key] ||= Set.new) << constant_name_of(reference)
        end
      end
    end

    def location_key(location, column:)
      [ location.uri, location.start_line, column ]
    end

    def constant_name_of(reference)
      if reference.is_a?(Rubydex::ResolvedConstantReference)
        reference.declaration.name
      else
        reference.name.delete_prefix("<").delete_suffix(">")
      end
    end

    def reference_location_key(reference)
      location_key(reference.location, column: reference.location.start_column)
    end

    class DocumentsChecksum
      def initialize(project_index)
        @project_index = project_index
      end

      def to_s
        Digest::SHA256.new.tap do |digest|
          documents.each do |document|
            digest << document.uri << "\0" << checksum_for(document) << "\0"
          end
        end.hexdigest
      end

      private
        attr_reader :project_index

        def documents
          project_index.documents.select { it.uri.start_with?(RuboCop::Cop::ProjectIndexHelp::FILE_URI_PREFIX) }
            .sort_by(&:uri)
        end

        def checksum_for(document)
          Digest::SHA256.file(path_for(document)).hexdigest
        rescue SystemCallError => error
          error.class.name
        end

        def path_for(document)
          RuboCop::Callbacksystems::ProjectIndex::SourceFile.for_document(document).path
        end
    end
end
