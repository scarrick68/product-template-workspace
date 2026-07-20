# frozen_string_literal: true

require "shellwords"

module Workspace
  module Services
    module Infra
      # Executes Terraform/OpenTofu commands for the configured infra workspace.
      class TerraformRunner
        SAFE_DESTROY_TARGETS = [
          "digitalocean_app.rails",
          "digitalocean_app.frontend"
        ].freeze

        def initialize(workspace:)
          @workspace = workspace
        end

        def init
          Workspace.info("Initializing infra working directory")
          run("init")
        end

        def plan
          Workspace.info("Running infra plan")
          run(
            "plan",
            "-var-file=#{Shellwords.escape(workspace.var_file_name)}",
            "-out=#{Shellwords.escape(workspace.plan_file_name)}"
          )
        end

        def apply
          Workspace.info("Running infra apply")
          run("apply", "-var-file=#{Shellwords.escape(workspace.var_file_name)}")
        end

        def safe_destroy
          Workspace.info("Running infra safe_destroy (preserving postgres/opensearch)")
          target_flags = SAFE_DESTROY_TARGETS.map { |target| "-target=#{Shellwords.escape(target)}" }
          run("destroy", "-var-file=#{Shellwords.escape(workspace.var_file_name)}", *target_flags)
        end

        def destroy
          Workspace.info("Running infra destroy")
          run("destroy", "-var-file=#{Shellwords.escape(workspace.var_file_name)}")
        end

        private

        attr_reader :workspace

        def run(subcommand, *flags)
          Workspace.run(terraform_command(subcommand, *flags), chdir: Workspace::ROOT)
        end

        def terraform_command(subcommand, *extra_flags)
          [
            Shellwords.escape(terraform_binary),
            "-chdir=#{Shellwords.escape(workspace.directory)}",
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
      end
    end
  end
end
