# frozen_string_literal: true

module Workspace
  module Services
    module Infra
      module Doctor
        # Validates that project.installation_id is present and formatted for infra naming.
        class InstallationIdCheck
          INSTALLATION_ID_PATTERN = /\A[a-f0-9]{6}\z/

          def initialize(manifest_configuration:, environment:)
            @manifest_configuration = manifest_configuration
            @environment = environment
          end

          def label
            "project installation_id"
          end

          def call
            config = manifest_configuration.read(environment: environment)
            installation_id = config["installation_id"].to_s.strip

            if installation_id.empty?
              Workspace.fail("project installation_id: missing")
              return false
            end

            unless installation_id.match?(INSTALLATION_ID_PATTERN)
              Workspace.fail("project installation_id: invalid (expected six lowercase hexadecimal characters)")
              return false
            end

            Workspace.ok("project installation_id: #{installation_id}")
            true
          end

          private

          attr_reader :manifest_configuration, :environment
        end
      end
    end
  end
end