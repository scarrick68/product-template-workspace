#!/usr/bin/env ruby
# frozen_string_literal: true
# Command object for infra utility scripts.
#
# Responsibilities:
# - Dispatch supported actions (`doctor`, `configure`, `plan`, `apply`) from a single entrypoint.
# - Validate local scaffold and required config before infra operations.
# - Generate config/infra.yml and terraform.tfvars.json from guided prompts.
# - Run `init` before `plan`/`apply` to keep provider/module state current.
# - Resolve Terraform/OpenTofu binary via INFRA_TERRAFORM_BIN or PATH.
# - Resolve var file via INFRA_VAR_FILE (default: terraform.tfvars.json).

require "shellwords"
require "json"
require "yaml"
require "tmpdir"
require "optparse"
require_relative "../../../workspace"
require_relative "../../../workspace/secrets/resolver"
require_relative "doctor_command"
require_relative "configure_wizard"
require_relative "tfvars_builder"
require_relative "spaces_bootstrapper"
require_relative "terraform_runner"
require_relative "rails_blob_credentials_sync"

module Workspace
  module Commands
    module Infra
      class ProvisionInfraCommand
      SUPPORTED_COMMANDS = %w[
        doctor
        doctor-config
        doctor-runtime
        doctor:config
        doctor:runtime
        configure
        plan
        apply
        bootstrap-spaces
      ].freeze
      TERRAFORM_DIR = File.join(Workspace::ROOT, "infra", "digitalocean")
      CONFIG_FILE = File.join(Workspace::ROOT, "config", "infra.yml")
      EXAMPLE_CONFIG_FILE = File.join(Workspace::ROOT, "config", "infra.example.yml")
      DEFAULT_VAR_FILE = "terraform.tfvars.json"
      DEFAULT_ENVIRONMENT = "production"
      DEFAULT_OPENSEARCH_SIZE = "db-s-1vcpu-2gb"

      def initialize(argv, stdin: $stdin, stdout: $stdout)
        @argv = argv.dup
        @stdin = stdin
        @stdout = stdout
        @secrets_resolver = Workspace::Secrets::Resolver.new(io: @stdout, input: @stdin)
      end

      def call
        action = requested_action
        return usage unless action

        case action
        when "doctor", "doctor-config", "doctor-runtime", "doctor:config", "doctor:runtime"
          run_doctor(action)
        when "configure"
          run_configure
        when "bootstrap-spaces"
          run_bootstrap_spaces
        else
          run_terraform_action(action)
        end
      end

      private

      attr_reader :argv, :stdin, :stdout

      def requested_action
        first_arg = argv.first
        return nil if first_arg.nil? || first_arg.strip.empty?
        return first_arg if SUPPORTED_COMMANDS.include?(first_arg)

        Workspace.fail_with_help(
          "Unsupported infra action '#{first_arg}'.",
          details: "Supported actions: #{SUPPORTED_COMMANDS.join(', ')}",
          fixes: [
            "Run: bin/infra doctor",
            "Run: bin/infra doctor production --phase=config",
            "Run: bin/infra doctor-runtime production",
            "Run: bin/infra configure production",
            "Run: bin/infra plan production",
            "Run: bin/infra apply production"
          ]
        )

        nil
      end

      def usage
        Workspace.info("Usage: bin/infra [doctor|doctor-config|doctor-runtime|configure|plan|apply|bootstrap-spaces] [environment] [--phase=config|runtime]")
        Workspace.info("Examples: bin/infra doctor production --phase=config | bin/infra doctor-runtime production | bin/infra configure production | bin/infra plan production")
        1
      end

      def run_doctor(action)
        options = parse_doctor_options(action)
        return 1 unless options

        DoctorCommand.new(
          config_file: CONFIG_FILE,
          terraform_var_file_path: terraform_var_file_path,
          terraform_var_file_name: terraform_var_file_name,
          phase: options[:phase],
          environment: options[:environment],
          terraform_runner: terraform_runner,
          secrets_resolver: @secrets_resolver,
          stdin: stdin,
          stdout: stdout
        ).call
      end

      def parse_doctor_options(action)
        phase = default_doctor_phase_for(action)
        args = argv[1..] || []

        parser = OptionParser.new do |opts|
          opts.on("--phase PHASE", "Doctor phase: config or runtime") do |value|
            normalized = value.to_s.strip
            unless %w[config runtime].include?(normalized)
              raise OptionParser::InvalidArgument, "phase must be config or runtime"
            end

            phase = normalized
          end

          opts.on("-h", "--help", "Show doctor usage") do
            Workspace.info("Usage: bin/infra doctor [environment] [--phase=config|runtime]")
            Workspace.info("Aliases: bin/infra doctor-config [environment] | bin/infra doctor-runtime [environment]")
            return nil
          end
        end

        parser.parse!(args)

        {
          environment: args[0].to_s.strip.empty? ? DEFAULT_ENVIRONMENT : args[0].to_s.strip,
          phase: phase
        }
      rescue OptionParser::ParseError => e
        Workspace.fail_with_help(
          "Invalid infra doctor options.",
          details: e.message,
          fixes: [
            "Run: bin/infra doctor production --phase=config",
            "Run: bin/infra doctor-runtime production"
          ]
        )
        nil
      end

      def default_doctor_phase_for(action)
        return "config" if ["doctor", "doctor-config", "doctor:config"].include?(action)

        "runtime"
      end

      def run_configure
        environment = requested_environment
        base_config = existing_infra_config
        ensure_digitalocean_access_token(interactive: true)
        Workspace.info("Starting guided infra configure flow for #{environment}.")
        Workspace.info("Press Enter to accept defaults shown in [brackets].")
        wizard = ConfigureWizard.new(
          stdin: stdin,
          stdout: stdout,
          default_opensearch_size: DEFAULT_OPENSEARCH_SIZE
        )
        config = wizard.collect(environment: environment, existing: base_config)

        write_infra_config!(config)
        write_terraform_var_file!(terraform_variables_for(config))

        Workspace.ok("infra configure completed for #{environment}")
        Workspace.info("Generated: config/infra.yml")
        Workspace.info("Generated: infra/digitalocean/#{terraform_var_file_name}")
        0
      end

      def run_bootstrap_spaces
        ensure_var_file_exists!
        token = ensure_digitalocean_access_token(interactive: true)
        spaces_bootstrapper.bootstrap!(
          tfvars: terraform_var_file_values,
          write_tfvars: method(:write_terraform_var_file!),
          doctl_access_token: token
        )
        0
      end

      def run_terraform_action(action)
        prepare_working_directory!
        token = ensure_digitalocean_access_token(interactive: true)
        if action == "apply"
          spaces_bootstrapper.bootstrap!(
            tfvars: terraform_var_file_values,
            write_tfvars: method(:write_terraform_var_file!),
            doctl_access_token: token,
            reason_action: action
          )
        end
        run_init
        run_action(action)
        synchronize_runtime_blob_config! if action == "apply"
        Workspace.ok("infra #{action} completed")
        0
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
        terraform_runner.init!
      end

      def run_action(action)
        terraform_runner.run_action!(action: action, var_file_name: terraform_var_file_name)
      end

      def requested_environment
        value = argv[1].to_s.strip
        return DEFAULT_ENVIRONMENT if value.empty?

        value
      end

      def existing_infra_config
        return {} unless File.exist?(CONFIG_FILE)

        YAML.safe_load(File.read(CONFIG_FILE), permitted_classes: [], aliases: false) || {}
      rescue Psych::SyntaxError
        {}
      end

      def write_infra_config!(config)
        File.write(CONFIG_FILE, config.to_yaml)
      end

      def write_terraform_var_file!(tfvars)
        path = terraform_var_file_path
        File.write(path, JSON.pretty_generate(tfvars) + "\n")
      end

      def terraform_variables_for(config)
        tfvars_builder.build(config)
      end

      def ensure_digitalocean_access_token(interactive:)
        token = @secrets_resolver.digitalocean_token(interactive: interactive)
        return nil if token.nil? || token.empty?

        token
      end

      def terraform_runner
        @terraform_runner ||= TerraformRunner.new(
          terraform_dir: TERRAFORM_DIR,
          workspace_root: Workspace::ROOT
        )
      end

      def terraform_var_file_name
        ENV.fetch("INFRA_VAR_FILE", DEFAULT_VAR_FILE).strip
      end

      def terraform_var_file_path
        File.join(TERRAFORM_DIR, terraform_var_file_name)
      end

      def terraform_var_file_values
        return {} unless File.exist?(terraform_var_file_path)

        JSON.parse(File.read(terraform_var_file_path))
      rescue JSON::ParserError
        {}
      end

      def spaces_bootstrapper
        @spaces_bootstrapper ||= SpacesBootstrapper.new(terraform_var_file_name: terraform_var_file_name)
      end

      def synchronize_runtime_blob_config!
        rails_blob_credentials_sync.sync!(
          tfvars: terraform_var_file_values,
          terraform_outputs: terraform_runner.output_values!
        )
      end

      def rails_blob_credentials_sync
        @rails_blob_credentials_sync ||= RailsBlobCredentialsSync.new(workspace_root: Workspace::ROOT)
      end

      def tfvars_builder
        @tfvars_builder ||= TfvarsBuilder.new(
          default_opensearch_size: DEFAULT_OPENSEARCH_SIZE,
          token_fetcher: -> { ensure_digitalocean_access_token(interactive: false) }
        )
      end
      end
    end
  end
end
