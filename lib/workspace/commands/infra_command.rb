#!/usr/bin/env ruby
# frozen_string_literal: true
# Command object for infra utility scripts.
#
# Responsibilities:
# - Dispatch supported actions (`plan`, `apply`) from a single entrypoint.
# - Validate required local scaffold inputs before shelling out.
# - Run `init` before every action to keep provider/module state current.
# - Resolve Terraform/OpenTofu binary via INFRA_TERRAFORM_BIN or PATH.
# - Resolve var file via INFRA_VAR_FILE (default: terraform.tfvars.json).

require "shellwords"
require_relative "../../workspace"

module Workspace
  module Commands
    class InfraCommand
      SUPPORTED_COMMANDS = %w[plan apply].freeze
      TERRAFORM_DIR = File.join(Workspace::ROOT, "infra", "digitalocean")
      DEFAULT_VAR_FILE = "terraform.tfvars.json"

      def initialize(argv)
        @argv = argv.dup
      end

      def call
        action = requested_action
        return usage unless action

        prepare_working_directory!
        run_init
        run_action(action)
        Workspace.ok("infra #{action} completed")
        0
      end

      private

      attr_reader :argv

      def requested_action
        first_arg = argv.first
        return nil if first_arg.nil? || first_arg.strip.empty?
        return first_arg if SUPPORTED_COMMANDS.include?(first_arg)

        Workspace.fail_with_help(
          "Unsupported infra action '#{first_arg}'.",
          details: "Supported actions: #{SUPPORTED_COMMANDS.join(', ')}",
          fixes: [
            "Run: bin/infra plan",
            "Run: bin/infra apply"
          ]
        )

        nil
      end

      def usage
        Workspace.info("Usage: bin/infra [plan|apply]")
        Workspace.info("Runs init first, then executes action in infra/digitalocean.")
        1
      end

      def prepare_working_directory!
        ensure_terraform_directory_exists!
        ensure_var_file_exists!
      end

      def ensure_terraform_directory_exists!
        return if Dir.exist?(TERRAFORM_DIR)

        Workspace.abort_with_help(
          "Terraform directory is missing.",
          details: "Expected directory: #{TERRAFORM_DIR}",
          fixes: [
            "Ensure infra scaffold exists under infra/digitalocean.",
            "Run this command from the product-template-workspace root."
          ]
        )
      end

      def ensure_var_file_exists!
        return if File.exist?(terraform_var_file_path)

        Workspace.abort_with_help(
          "Missing Terraform var-file.",
          details: "Expected file: #{terraform_var_file_path}",
          fixes: [
            "Create infra/digitalocean/#{terraform_var_file_name} with environment values.",
            "Populate required keys listed in infra/digitalocean/variables.tf."
          ]
        )
      end

      def run_init
        Workspace.info("Initializing infra working directory")
        Workspace.run(terraform_command("init"), chdir: Workspace::ROOT)
      end

      def run_action(action)
        Workspace.info("Running infra #{action}")
        Workspace.run(
          terraform_command(action, "-var-file=#{Shellwords.escape(terraform_var_file_name)}"),
          chdir: Workspace::ROOT
        )
      end

      def terraform_command(subcommand, *extra_flags)
        [
          Shellwords.escape(terraform_binary),
          "-chdir=#{Shellwords.escape(TERRAFORM_DIR)}",
          subcommand,
          *extra_flags
        ].join(" ")
      end

      def terraform_binary
        @terraform_binary ||= begin
          configured_binary = ENV.fetch("INFRA_TERRAFORM_BIN", "").strip
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

      def terraform_var_file_name
        ENV.fetch("INFRA_VAR_FILE", DEFAULT_VAR_FILE).strip
      end

      def terraform_var_file_path
        File.join(TERRAFORM_DIR, terraform_var_file_name)
      end
    end
  end
end
