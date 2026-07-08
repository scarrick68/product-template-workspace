#!/usr/bin/env ruby
# frozen_string_literal: true

require "shellwords"
require "json"
require_relative "../../../workspace"

module Workspace
  module Commands
    module Infra
      class TerraformRunner
        def initialize(terraform_dir:, workspace_root:, env: ENV)
          @terraform_dir = terraform_dir
          @workspace_root = workspace_root
          @env = env
        end

        def init!
          Workspace.info("Initializing infra working directory")
          Workspace.run(terraform_command("init"), chdir: workspace_root)
        end

        def run_action!(action:, var_file_name:)
          Workspace.info("Running infra #{action}")
          Workspace.run(
            terraform_command(action, "-var-file=#{Shellwords.escape(var_file_name)}"),
            chdir: workspace_root
          )
        end

        def output_values!
          output, success = Workspace.capture(terraform_command("output", "-json"), chdir: workspace_root)
          unless success
            Workspace.abort_with_help(
              "Unable to read Terraform outputs.",
              details: "terraform output -json failed in #{terraform_dir}.",
              fixes: [
                "Run: #{terraform_binary} -chdir=#{terraform_dir} output -json",
                "Fix the reported Terraform issue and retry bin/infra apply."
              ]
            )
          end

          parse_output_values(output)
        end

        private

        attr_reader :terraform_dir, :workspace_root, :env

        def parse_output_values(output)
          parsed = JSON.parse(output)
          parsed.each_with_object({}) do |(key, value), acc|
            acc[key] = value.fetch("value")
          end
        rescue JSON::ParserError
          Workspace.abort_with_help(
            "Unable to parse Terraform outputs.",
            details: "terraform output -json returned invalid JSON.",
            fixes: [
              "Run terraform output -json manually to inspect output.",
              "Fix Terraform output issues and retry bin/infra apply."
            ]
          )
        end

        def terraform_command(subcommand, *extra_flags)
          [
            Shellwords.escape(terraform_binary),
            "-chdir=#{Shellwords.escape(terraform_dir)}",
            subcommand,
            *extra_flags
          ].join(" ")
        end

        def terraform_binary
          @terraform_binary ||= begin
            configured_binary = env.fetch("INFRA_TERRAFORM_BIN", "").strip
            return configured_binary unless configured_binary.empty?
            return "terraform" if Workspace.command_exists?("terraform")
            return "tofu" if Workspace.command_exists?("tofu")

            Workspace.abort_with_help(
              "Terraform/OpenTofu CLI not found.",
              details: "Install terraform/tofu or set INFRA_TERRAFORM_BIN.",
              fixes: [
                "Install Terraform: https://developer.hashicorp.com/terraform/install",
                "Install OpenTofu: https://opentofu.org/docs/intro/install/",
                "Export INFRA_TERRAFORM_BIN=/path/to/terraform"
              ]
            )
          end
        end
      end
    end
  end
end