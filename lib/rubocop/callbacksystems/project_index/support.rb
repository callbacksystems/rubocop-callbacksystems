module RuboCop::Callbacksystems::ProjectIndex::Support
  include RuboCop::Cop::ProjectIndexHelp

  def external_dependency_checksum
    RuboCop::Callbacksystems::ProjectIndex::Reading.for(project_index).checksum if project_index
  end

  private
    def project_index_reliable?
      project_index && RuboCop::Callbacksystems::ProjectIndex::Freshness.reliable?(project_index) &&
        source_matches_index? && RuboCop::Callbacksystems::ProjectIndex::Reading.for(project_index).reliable?
    end

    def source_matches_index?
      source_matches_disk? ||
        RuboCop::Callbacksystems::ProjectIndex::Freshness.current_source?(project_index, processed_source)
    end

    def source_matches_disk?
      RuboCop::Callbacksystems::ProjectIndex::SourceFileMatch.for(processed_source)
    end

    def confined_declaration_of(nested_class)
      resolve_constant_in_index(nested_class.identifier).then do |declaration|
        declaration if confined_to_current_file?(declaration, nested_class:)
      end
    end

    def confined_to_current_file?(declaration, nested_class:)
      declaration.is_a?(Rubydex::Class) && project_declaration_reliable?(declaration) &&
        definitions_in_other_files(declaration.definitions).empty? && declaration.definitions.one? &&
        RuboCop::Callbacksystems::ProjectIndex::ConfinementCache
          .for(nested_class, declaration:, project_index:).confined?
    end

    def project_declaration_reliable?(declaration)
      !project_index_diagnostics.within_definitions?(
        declaration.definitions,
        named: [ "InvalidMethodVisibility" ]
      )
    end

    def project_index_diagnostics
      RuboCop::Callbacksystems::ProjectIndex::Diagnostics.for(project_index)
    end
end
