# frozen_string_literal: true

module Workspace
  module Services
    module Infra
      module Doctor
        class CliAvailabilityChecks
          class CommandAvailableCheck
            def initialize(label:, status_label:, commands:)
              @label = label
              @status_label = status_label
              @commands = commands
            end

            attr_reader :label

            def call
              found = commands.find { |name| Workspace.command_exists?(name) }
              if found
                Workspace.ok("#{status_label}: #{found}")
                return true
              end

              Workspace.fail("#{status_label}: missing (checked #{commands.join(', ')})")
              false
            end

            private

            attr_reader :status_label, :commands
          end

          def to_a
            [
              CommandAvailableCheck.new(label: "Terraform/OpenTofu CLI", status_label: "Terraform/OpenTofu", commands: ["terraform", "tofu"]),
              CommandAvailableCheck.new(label: "doctl CLI", status_label: "doctl", commands: ["doctl"]),
              CommandAvailableCheck.new(label: "GitHub CLI", status_label: "GitHub CLI", commands: ["gh"]),
              CommandAvailableCheck.new(label: "git CLI", status_label: "git", commands: ["git"])
            ]
          end
        end
      end
    end
  end
end
