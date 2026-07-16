#!/usr/bin/env ruby
# frozen_string_literal: true
# Command object for infra utility scripts.
#
# Responsibilities:
# - Dispatch supported actions (`doctor`, `configure`, `plan`, `apply`) from a single entrypoint.
# - Validate local scaffold and required config before infra operations.
# - Generate config/project.yml environment infrastructure and terraform.tfvars.json from guided prompts.
# - Run `init` before `plan`/`apply` to keep provider/module state current.
# - Resolve Terraform/OpenTofu binary via INFRA_TERRAFORM_BIN or PATH.
# - Resolve var file via INFRA_VAR_FILE (default: terraform.tfvars.json).

require "json"
require "yaml"
require "tty-prompt"
require_relative "../../../workspace"
require_relative "../../../workspace/secrets/resolver"
require_relative "./command_line_options"
require_relative "./blob_storage_manager"
require_relative "./configuration_prompt"
require_relative "./credentials"
require_relative "./doctor/blob_storage_check"
require_relative "./doctor/cli_availability_checks"
require_relative "./doctor/provider_authentication_checks"
require_relative "./doctor/repository_check"
require_relative "./doctor/runner"
require_relative "./manifest_configuration"
require_relative "./terraform_preflight"
require_relative "./terraform_workspace"
require_relative "./terraform_runner"
require_relative "./terraform_variables"

module Workspace
  module Services
    module Infra
      class ProvisionInfra
        PROJECT_MANIFEST_FILE = File.join(Workspace::ROOT, "config", "project.yml")

        def initialize(argv, stdin: $stdin, stdout: $stdout)
          @argv = argv.dup
          @stdin = stdin
          @stdout = stdout
          @prompt = TTY::Prompt.new(input: @stdin, output: @stdout)
          @secrets_resolver = Workspace::Secrets::Resolver.new(stdout: @stdout, stdin: @stdin)
          @credentials = Workspace::Services::Infra::Credentials.new(secrets_resolver: @secrets_resolver)
          @manifest_configuration = Workspace::Services::Infra::ManifestConfiguration.new(root: Workspace::ROOT)
          @blob_storage_manager = Workspace::Services::Infra::BlobStorageManager.new(
            manifest_configuration: @manifest_configuration,
            secrets_resolver: @secrets_resolver,
            stdin: @stdin
          )
          @terraform_workspace = Workspace::Services::Infra::TerraformWorkspace.new
          @terraform_runner = Workspace::Services::Infra::TerraformRunner.new(workspace: @terraform_workspace)
          @terraform_preflight = Workspace::Services::Infra::TerraformPreflight.new(workspace: @terraform_workspace)
        end

        def call
          options = CommandLineOptions.parse(argv)
          return options.exit_code unless options.valid?

          case options.action
          when "doctor"
            run_doctor(options.environment)
          when "configure"
            run_configure(options.environment)
          else
            run_terraform_action(options.action, options.environment)
          end
        end

        private

        attr_reader :argv, :stdin, :stdout, :prompt

        def run_doctor(environment)
          cli_checks = Workspace::Services::Infra::Doctor::CliAvailabilityChecks.new.to_a

          provider_checks = Workspace::Services::Infra::Doctor::ProviderAuthenticationChecks.new(
            credentials: credentials
          ).to_a

          checks = [
            *cli_checks,
            *provider_checks,
            Workspace::Services::Infra::Doctor::RepositoryCheck.new,
            Workspace::Services::Infra::Doctor::BlobStorageCheck.new(
              manifest_configuration: manifest_configuration,
              environment: environment,
              secrets_resolver: secrets_resolver
            )
          ]

          Workspace::Services::Infra::Doctor::Runner.new(checks: checks).call
        end

        def run_configure(environment)
          base_config = manifest_configuration.read(environment: environment)
          credentials.export_terraform_environment!(interactive: true)
          Workspace.info("Starting guided infra configure flow for #{environment}.")
          Workspace.info("Press Enter to accept defaults shown in [brackets].")
          config = Workspace::Services::Infra::ConfigurationPrompt.new(
            prompt: prompt,
            output: stdout
          ).call(environment: environment, defaults: base_config)

          manifest_configuration.write(environment: environment, configuration: config)
          write_terraform_var_file!(Workspace::Services::Infra::TerraformVariables.new(config).to_h)

          Workspace.ok("infra configure completed for #{environment}")
          Workspace.info("Generated: config/project.yml")
          Workspace.info("Generated: infra/digitalocean_v2/#{terraform_workspace.var_file_name}")
          0
        end

        def run_terraform_action(action, environment)
          terraform_preflight.check!
          credentials.export_terraform_environment!(interactive: true)
          blob_storage_manager.ensure_spaces_credentials_for_provisioning(environment: environment, interactive: true)
          terraform_runner.init

          case action
          when "plan"
            terraform_runner.plan
          when "apply"
            terraform_runner.apply
          when "safe_destroy"
            terraform_runner.safe_destroy
          when "total_destruction"
            terraform_runner.destroy
          end

          Workspace.ok("infra #{action} completed")
          0
        end

        def write_terraform_var_file!(tfvars)
          path = terraform_workspace.var_file_path
          File.write(path, JSON.pretty_generate(tfvars) + "\n")
        end

        def manifest_configuration
          @manifest_configuration
        end

        def credentials
          @credentials
        end

        def blob_storage_manager
          @blob_storage_manager
        end

        def terraform_workspace
          @terraform_workspace
        end

        def terraform_runner
          @terraform_runner
        end

        def terraform_preflight
          @terraform_preflight
        end

        def secrets_resolver
          @secrets_resolver
        end
      end
    end
  end
end
