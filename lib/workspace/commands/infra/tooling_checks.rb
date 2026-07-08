#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../../../workspace"

module Workspace
  module Commands
    module Infra
      class ToolingChecks
        def cli_available?(commands, label)
          found = commands.find { |name| Workspace.command_exists?(name) }
          if found
            Workspace.ok("#{label}: #{found}")
            return true
          end

          Workspace.fail("#{label}: missing (checked #{commands.join(', ')})")
          false
        end

        def terraform_cli_available?
          cli_available?(["terraform"], "Terraform CLI")
        end

        def open_tofu_cli_available?
          cli_available?(["tofu"], "OpenTofu CLI")
        end

        def digital_ocean_cli_available?
          cli_available?(["doctl"], "doctl")
        end

        def github_cli_available?
          cli_available?(["gh"], "GitHub CLI")
        end

        def git_cli_available?
          cli_available?(["git"], "git")
        end

        def amazon_web_services_cli_available?
          cli_available?(["aws"], "AWS CLI")
        end

        def digital_ocean_auth_valid?
          unless Workspace.command_exists?("doctl")
            Workspace.fail("doctl auth: cannot verify (doctl missing)")
            return false
          end

          _out, success = Workspace.capture("doctl account get")
          if success
            Workspace.ok("doctl auth: valid")
            return true
          end

          Workspace.fail("doctl auth: invalid (run: doctl auth init)")
          false
        end

        def github_auth_valid?
          unless Workspace.command_exists?("gh")
            Workspace.fail("gh auth: cannot verify (gh missing)")
            return false
          end

          _out, success = Workspace.capture("gh auth status")
          if success
            Workspace.ok("gh auth: valid")
            return true
          end

          Workspace.fail("gh auth: invalid (run: gh auth login)")
          false
        end

      end
    end
  end
end