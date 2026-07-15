# frozen_string_literal: true

module Workspace
  module Services
    module LocalEnvSetup
      module Config
        class ServiceConfig
          attr_reader :id, :label, :command, :installer_class

          def initialize(id:, label:, command:, installer_class: nil)
            @id = id
            @label = label
            @command = command
            @installer_class = installer_class
          end

          def ruby?
            id == "ruby"
          end

          def installable?
            !installer_class.nil?
          end

          def self.required_tools
            @required_tools ||= [
              new(id: "ruby", label: "Ruby", command: "ruby", installer_class: Workspace::Services::LocalEnvSetup::Installers::InstallRuby),
              new(id: "docker", label: "Docker", command: "docker", installer_class: Workspace::Services::LocalEnvSetup::Installers::InstallDocker),
              new(id: "doctl", label: "doctl", command: "doctl", installer_class: Workspace::Services::LocalEnvSetup::Installers::InstallDoctl),
              new(id: "gh", label: "GitHub CLI", command: "gh", installer_class: Workspace::Services::LocalEnvSetup::Installers::InstallGh),
              new(id: "terraform", label: "Terraform", command: "terraform", installer_class: Workspace::Services::LocalEnvSetup::Installers::InstallTerraform)
            ].freeze
          end
        end
      end
    end
  end
end
