# frozen_string_literal: true

module Workspace
  module Services
    module LocalEnvSetup
      module Config
        class ServiceAuthConfig
          attr_reader :id, :command, :status_command, :success_message, :preference_key, :prompt, :auth_command,
                      :failure_summary, :failure_details, :failure_fixes

          def initialize(id:, command:, status_command:, success_message:, preference_key:, prompt:, auth_command:, failure_summary:, failure_details:, failure_fixes:)
            @id = id
            @command = command
            @status_command = status_command
            @success_message = success_message
            @preference_key = preference_key
            @prompt = prompt
            @auth_command = auth_command
            @failure_summary = failure_summary
            @failure_details = failure_details
            @failure_fixes = failure_fixes
          end

          def self.github_cli
            new(
              id: "gh",
              command: "gh",
              status_command: "gh auth status",
              success_message: "GitHub CLI auth: configured",
              preference_key: "gh_auth",
              prompt: "GitHub CLI is not authenticated. Run gh auth login now?",
              auth_command: "gh auth login",
              failure_summary: "GitHub CLI authentication failed.",
              failure_details: "gh auth login did not complete successfully.",
              failure_fixes: [
                "Retry gh auth login and complete prompts.",
                "If using SSO orgs, authorize token access after login."
              ]
            )
          end

          def self.doctl
            new(
              id: "doctl",
              command: "doctl",
              status_command: "doctl auth list",
              success_message: "doctl auth: configured",
              preference_key: "doctl_auth",
              prompt: "doctl is not authenticated. Run doctl auth init now? (You will need a DigitalOcean API token.)",
              auth_command: "doctl auth init",
              failure_summary: "doctl authentication failed.",
              failure_details: "doctl auth init did not complete successfully.",
              failure_fixes: [
                "Retry doctl auth init and provide a valid token.",
                "Confirm token scope includes required DigitalOcean permissions."
              ]
            )
          end

          def self.all
            @all ||= [github_cli, doctl].freeze
          end
        end
      end
    end
  end
end
