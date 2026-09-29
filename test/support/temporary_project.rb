require "tmpdir"

module TemporaryProject
  extend ActiveSupport::Concern

  included do
    teardown { @project&.remove }
  end

  private
    delegate :create_file, to: :project, private: true

    def project
      @project ||= ProjectDirectory.new(Dir.mktmpdir)
    end
end
