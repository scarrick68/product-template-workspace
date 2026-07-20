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
require "securerandom"
require "yaml"
require "tty-prompt"
require_relative "../../../workspace"
require_relative "../../../workspace/secrets/resolver"
require_relative "./command_line_options"
require_relative "./blob_storage_manager"
require_relative "./configuration_prompt"
require_relative "./cors_origin_synchronizer"
require_relative "./credentials"
require_relative "./digital_ocean/admin_bootstrap"
require_relative "./digital_ocean/blazer_bootstrap"
require_relative "./digital_ocean/github_app_authorization"
require_relative "./doctor/blob_storage_check"
require_relative "./doctor/cli_availability_checks"
require_relative "./doctor/installation_id_check"
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
        TEMPLATE_INSTALLATION_ID = "000000"
        INSTALLATION_ID_PATTERN = /\A[a-f0-9]{6}\z/
        INSTALLATION_ID_HEX_BYTES = 3

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
          @github_app_authorization = Workspace::Services::Infra::Digitalocean::GithubAppAuthorization.new(
            prompt: @prompt,
            stdin: @stdin,
            stdout: @stdout
          )
          @terraform_workspace = Workspace::Services::Infra::TerraformWorkspace.new
          @terraform_runner = Workspace::Services::Infra::TerraformRunner.new(workspace: @terraform_workspace)
          @terraform_preflight = Workspace::Services::Infra::TerraformPreflight.new(workspace: @terraform_workspace)
          @cors_origin_synchronizer = Workspace::Services::Infra::CorsOriginSynchronizer.new(
            manifest_configuration: @manifest_configuration,
            terraform_workspace: @terraform_workspace,
            workspace: Workspace
          )
          @admin_bootstrap = Workspace::Services::Infra::Digitalocean::AdminBootstrap.new(
            terraform_workspace: @terraform_workspace,
            stdin: @stdin,
            stdout: @stdout
          )
          @blazer_bootstrap = Workspace::Services::Infra::Digitalocean::BlazerBootstrap.new(
            terraform_workspace: @terraform_workspace,
            stdin: @stdin,
            stdout: @stdout
          )
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
            run_terraform_action(options.action, options.environment, first_deploy_setup: options.first_deploy_setup)
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
            Workspace::Services::Infra::Doctor::InstallationIdCheck.new(
              manifest_configuration: manifest_configuration,
              environment: environment
            ),
            Workspace::Services::Infra::Doctor::BlobStorageCheck.new(
              manifest_configuration: manifest_configuration,
              environment: environment,
              secrets_resolver: secrets_resolver
            )
          ]

          Workspace::Services::Infra::Doctor::Runner.new(checks: checks).call
        end

        def run_configure(environment)
          installation_id = ensure_manifest_installation_id!
          return 1 if installation_id.empty?

          base_config = manifest_configuration.read(environment: environment)
          installation_id = base_config["installation_id"].to_s.strip if base_config["installation_id"].to_s.strip != ""
          project_slug = base_config["project_slug"].to_s.strip

          credentials.export_terraform_environment!(interactive: true)
          Workspace.info("Starting guided infra configure flow for #{environment}.")
          Workspace.info("Press Enter to accept defaults shown in [brackets].")
          config = Workspace::Services::Infra::ConfigurationPrompt.new(
            prompt: prompt,
            output: stdout
          ).call(environment: environment, defaults: base_config)

          config["project_slug"] = project_slug
          config["installation_id"] = installation_id

          return 1 unless run_github_authorization_step(config)

          manifest_configuration.write(environment: environment, configuration: config)
          write_terraform_var_file!(Workspace::Services::Infra::TerraformVariables.new(config).to_h)

          Workspace.ok("infra configure completed for #{environment}")
          Workspace.ok("GitHub authorization step completed")
          Workspace.info("Generated: config/project.yml")
          Workspace.info("Generated: infra/digitalocean_v2/#{terraform_workspace.var_file_name}")
          0
        end

        def run_github_authorization_step(config)
          repositories = github_source_repositories(config)
          return true if repositories.empty?

          authorized = github_app_authorization.call(repositories: repositories)
          return true if authorized

          Workspace.fail_with_help(
            "GitHub authorization step not completed.",
            details: "DigitalOcean needs repository access before Terraform can create App Platform components from GitHub sources.",
            fixes: [
              "Run: bin/infra configure production",
              "Grant access to all listed repositories when the browser opens.",
              "Stop at the DigitalOcean Create App screen and return to the terminal."
            ]
          )
          false
        end

        def github_source_repositories(config)
          github = config["github"] || {}
          owner = github["owner"].to_s.strip
          api_repo = github["api_repo"].to_s.strip
          web_repo = github["web_repo"].to_s.strip
          return [] if owner.empty?

          repositories = []
          repositories << "#{owner}/#{api_repo}" unless api_repo.empty?
          repositories << "#{owner}/#{web_repo}" unless web_repo.empty?
          repositories
        end

        def run_terraform_action(action, environment, first_deploy_setup: false)
          terraform_preflight.check!
          credentials.export_terraform_environment!(interactive: true)
          blob_storage_manager.ensure_spaces_credentials_for_provisioning(environment: environment, interactive: true)
          terraform_runner.init

          case action
          when "plan"
            terraform_runner.plan
          when "apply"
            apply_with_backend_cors_synchronization(environment: environment)
            if first_deploy_setup
              return 1 unless blazer_bootstrap.call(environment: environment)
              return 1 unless admin_bootstrap.call(environment: environment)
            else
              Workspace.info("Skipping first-deploy setup steps (Blazer and admin bootstrap).")
              Workspace.info("Run 'bin/workspace infra apply #{environment} --first-deploy-setup' when performing initial production bootstrap.")
            end
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

        def ensure_manifest_installation_id!
          manifest = YAML.safe_load_file(PROJECT_MANIFEST_FILE, permitted_classes: [], aliases: false) || {}
          project = manifest["project"]
          project = manifest["project"] = {} unless project.is_a?(Hash)

          existing = project["installation_id"].to_s.strip
          return existing if existing.match?(INSTALLATION_ID_PATTERN) && existing != TEMPLATE_INSTALLATION_ID

          installation_id = SecureRandom.hex(INSTALLATION_ID_HEX_BYTES)
          project["installation_id"] = installation_id
          File.write(PROJECT_MANIFEST_FILE, YAML.dump(manifest))
          Workspace.info("Assigned project installation_id: #{installation_id}")
          installation_id
        rescue Errno::ENOENT
          Workspace.fail_with_help(
            "Missing project manifest.",
            details: "Expected file: #{PROJECT_MANIFEST_FILE}",
            fixes: [
              "Ensure you are running this command from the workspace root.",
              "Restore config/project.yml and re-run infra configure."
            ]
          )
          ""
        end

        def apply_with_backend_cors_synchronization(environment:)
          cors_origin_synchronizer.ensure_backend_cors_origin_value_for_initial_apply!(environment: environment)
          terraform_runner.apply

          cors_updated = cors_origin_synchronizer.fill_backend_cors_origin_from_live_frontend_url_if_missing!
          return unless cors_updated

          Workspace.info("Applying again to push filled backend CORS origin into App Platform.")
          terraform_runner.apply
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

        def github_app_authorization
          @github_app_authorization
        end

        def cors_origin_synchronizer
          @cors_origin_synchronizer
        end

        def admin_bootstrap
          @admin_bootstrap
        end

        def blazer_bootstrap
          @blazer_bootstrap
        end

        def secrets_resolver
          @secrets_resolver
        end
      end
    end
  end
end
