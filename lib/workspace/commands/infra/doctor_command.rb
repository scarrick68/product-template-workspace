#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "yaml"
require_relative "../../../workspace"
require_relative "../../../workspace/secrets/resolver"
require_relative "tooling_checks"
require_relative "resource_availability"
require_relative "project_structure_doctor_command"
require_relative "terraform_runner"

module Workspace
  module Commands
    module Infra
      class DoctorCommand
        DIGITALOCEAN_TOKEN_KEY = "DIGITALOCEAN_ACCESS_TOKEN"
        VALID_PHASES = %w[config runtime].freeze

        def initialize(config_file:, terraform_var_file_path:, terraform_var_file_name:, phase: "config", environment: "production", terraform_runner: nil, secrets_resolver: nil, tooling_checks: nil, stdin: $stdin, stdout: $stdout)
          @config_file = config_file
          @terraform_var_file_path = terraform_var_file_path
          @terraform_var_file_name = terraform_var_file_name
          @phase = normalize_phase(phase)
          @environment = environment.to_s.strip.empty? ? "production" : environment.to_s.strip
          @stdin = stdin
          @stdout = stdout
          @secrets_resolver = secrets_resolver || Workspace::Secrets::Resolver.new(io: @stdout, input: @stdin)
          @tooling_checks = tooling_checks || ToolingChecks.new
          @terraform_runner = terraform_runner || TerraformRunner.new(
            terraform_dir: File.join(Workspace::ROOT, "infra", "digitalocean"),
            workspace_root: Workspace::ROOT
          )
        end

        def call
          Workspace.info("Running infra doctor phase=#{phase} environment=#{environment}")
          checks = phase == "runtime" ? runtime_checks : config_checks

          failed_checks = []
          checks.each do |label, check|
            failed_checks << label unless check.call
          end

          unless failed_checks.empty?
            Workspace.info("infra doctor (phase=#{phase}) failed checks: #{failed_checks.join(', ')}")
            Workspace.fail("infra doctor detected one or more issues")
            return 1
          end

          Workspace.ok("infra doctor (phase=#{phase}) checks passed")
          0
        end

        private

        attr_reader :config_file, :terraform_var_file_path, :terraform_var_file_name, :phase, :environment, :stdin, :stdout, :secrets_resolver, :tooling_checks, :terraform_runner

        def config_checks
          [
            ["Terraform/OpenTofu CLI", -> { check_terraform_or_open_tofu_cli_available }],
            ["doctl CLI", -> { tooling_checks.digital_ocean_cli_available? }],
            ["GitHub CLI", -> { tooling_checks.github_cli_available? }],
            ["git CLI", -> { tooling_checks.git_cli_available? }],
            [DIGITALOCEAN_TOKEN_KEY, -> { check_digitalocean_access_token }],
            ["rails master key accessibility", -> { check_rails_master_key_accessibility }],
            ["doctl auth", -> { tooling_checks.digital_ocean_auth_valid?(access_token: resolved_digitalocean_access_token) }],
            ["gh auth", -> { tooling_checks.github_auth_valid? }],
            ["project structure", -> { project_structure_doctor.call }],
            ["expected repositories", -> { check_expected_repositories }],
            ["blob store config readiness", -> { check_blob_store_config_readiness }]
          ]
        end

        def runtime_checks
          [
            ["Terraform/OpenTofu CLI", -> { check_terraform_or_open_tofu_cli_available }],
            ["rails master key accessibility", -> { check_rails_master_key_accessibility }],
            ["project structure", -> { project_structure_doctor.call }],
            ["terraform outputs", -> { check_runtime_outputs_presence }],
            ["database runtime value", -> { check_runtime_database_readiness }],
            ["blob store runtime values", -> { check_blob_store_runtime_readiness }]
          ]
        end

        def check_rails_master_key_accessibility
          key = resolved_rails_master_key
          if key.to_s.strip.empty?
            Workspace.warn("RAILS_MASTER_KEY: not accessible via env or backend repo config/master.key yet")
          else
            Workspace.ok("RAILS_MASTER_KEY: accessible via env or backend repo")
          end

          true
        end

        def check_digitalocean_access_token
          token = resolved_digitalocean_access_token
          if token
            Workspace.ok("#{DIGITALOCEAN_TOKEN_KEY}: available")
            return true
          end

          Workspace.fail("#{DIGITALOCEAN_TOKEN_KEY}: missing")
          false
        end

        def check_terraform_or_open_tofu_cli_available
          return tooling_checks.terraform_cli_available? if Workspace.command_exists?("terraform")

          tooling_checks.open_tofu_cli_available?
        end

        def check_expected_repositories
          all_found = true
          targets = {
            "backend-api" => default_repo_name("backend-api", "api-template"),
            "frontend-web-client" => default_repo_name("frontend-web-client", "web-template")
          }

          targets.each do |purpose, name|
            repo = Workspace.repositories.find { |item| item["purpose"].to_s == purpose }
            path = repo && repo["path"]
            absolute_path = path && File.join(Workspace::ROOT, path)

            if absolute_path && Dir.exist?(absolute_path)
              Workspace.ok("repo #{name}: found")
            else
              Workspace.fail("repo #{name}: missing")
              all_found = false
            end
          end

          all_found
        end

        def check_blob_store_config_readiness
          config = existing_infra_config
          availability = ResourceAvailability.from_infra_config(config)
          return true unless availability.blob_store_enabled?

          provider = availability.blob_store_provider
          return true if provider.to_s.empty?

          if provider == "aws_s3"
            return check_aws_s3_config_readiness
          end

          if provider == "digitalocean_spaces"
            return check_digitalocean_spaces_config_readiness
          end

          Workspace.fail("blob storage provider '#{provider}': unsupported (expected digitalocean_spaces or aws_s3)")
          false
        end

        def check_digitalocean_spaces_config_readiness
          tfvars = terraform_var_file_values
          should_create_bucket = tfvars.fetch("spaces_create_bucket", true)
          should_create_key = tfvars.fetch("spaces_create_key", true)

          unless should_create_bucket || should_create_key
            access_key = tfvars["spaces_access_key_id"]
            secret_key = tfvars["spaces_secret_access_key"]

            if blank_or_placeholder?(access_key) || blank_or_placeholder?(secret_key)
              Workspace.fail("DigitalOcean Spaces credentials: missing in #{terraform_var_file_name} (spaces_access_key_id/spaces_secret_access_key)")
              return false
            end

            Workspace.ok("DigitalOcean Spaces credentials: present (external/user-supplied)")
            return true
          end

          if should_create_key
            Workspace.ok("DigitalOcean Spaces credentials: managed by Terraform (expected missing pre-apply)")
            return true
          end

          access_key = tfvars["spaces_access_key_id"]
          secret_key = tfvars["spaces_secret_access_key"]

          if blank_or_placeholder?(access_key) || blank_or_placeholder?(secret_key)
            Workspace.fail("DigitalOcean Spaces credentials: missing in #{terraform_var_file_name} (spaces_access_key_id/spaces_secret_access_key)")
            return false
          end

          Workspace.ok("DigitalOcean Spaces credentials: present")
          true
        end

        def check_aws_s3_config_readiness
          Workspace.info("blob storage provider aws_s3: checking CLI/auth readiness")

          return false unless tooling_checks.amazon_web_services_cli_available?

          _out, success = Workspace.capture("aws sts get-caller-identity")
          if success
            Workspace.ok("AWS auth: valid")
            return true
          end

          Workspace.fail("AWS auth: invalid (run: aws configure, then aws sts get-caller-identity)")
          false
        end

        def check_runtime_outputs_presence
          outputs = runtime_outputs
          unless outputs
            Workspace.fail("terraform outputs: unavailable (run: bin/infra apply #{environment})")
            return false
          end

          tfvars = terraform_var_file_values
          required_keys = required_runtime_output_keys(tfvars)
          missing_keys = required_keys.select { |key| blank_or_placeholder?(outputs[key]) }

          if missing_keys.empty?
            Workspace.ok("terraform outputs: expected keys are present")
            return true
          end

          Workspace.fail("terraform outputs: missing or blank keys #{missing_keys.join(', ')}")
          false
        end

        def check_runtime_database_readiness
          outputs = runtime_outputs
          return true unless outputs

          tfvars = terraform_var_file_values
          return true unless tfvars["enable_postgres"] == true

          database_url = outputs["database_url"]
          if blank_or_placeholder?(database_url)
            Workspace.fail("runtime database_url: missing while enable_postgres=true")
            return false
          end

          Workspace.ok("runtime database_url: present")
          true
        end

        def check_blob_store_runtime_readiness
          outputs = runtime_outputs
          return true unless outputs

          tfvars = terraform_var_file_values
          availability = ResourceAvailability.from_infra_config(
            existing_infra_config,
            overrides: {
              blob_store_enabled: tfvars["enable_spaces"],
              blob_store_provider: tfvars["spaces_provider"]
            }
          )
          return true unless availability.blob_store_enabled?

          provider = availability.blob_store_provider
          return true if provider.to_s.empty?

          unless %w[digitalocean_spaces aws_s3].include?(provider)
            Workspace.fail("blob storage provider '#{provider}': unsupported (expected digitalocean_spaces or aws_s3)")
            return false
          end

          required = %w[spaces_bucket aws_access_key_id aws_secret_access_key]
          required << "s3_endpoint" if provider == "digitalocean_spaces"
          missing = required.select { |key| blank_or_placeholder?(outputs[key]) }

          if missing.empty?
            Workspace.ok("blob store runtime values: present")
            return true
          end

          Workspace.fail("blob store runtime values: missing or blank keys #{missing.join(', ')}")
          false
        end

        def ensure_digitalocean_access_token(interactive:)
          token = secrets_resolver.digitalocean_token(interactive: interactive)
          return nil if token.nil? || token.empty?

          token
        end

        def resolved_digitalocean_access_token
          return @resolved_digitalocean_access_token if defined?(@resolved_digitalocean_access_token)

          @resolved_digitalocean_access_token = ensure_digitalocean_access_token(interactive: false)
        end

        def existing_infra_config
          return {} unless File.exist?(config_file)

          YAML.safe_load(File.read(config_file), permitted_classes: [], aliases: false) || {}
        rescue Psych::SyntaxError
          {}
        end

        def terraform_var_file_values
          return {} unless File.exist?(terraform_var_file_path)

          JSON.parse(File.read(terraform_var_file_path))
        rescue JSON::ParserError
          {}
        end

        def default_repo_name(purpose, fallback)
          repo = Workspace.repositories.find { |item| item["purpose"].to_s == purpose }
          return fallback unless repo

          repo["name"].to_s.empty? ? fallback : repo["name"].to_s
        end

        def project_structure_doctor
          @project_structure_doctor ||= ProjectStructureDoctorCommand.new(
            config_file: config_file,
            terraform_var_file_path: terraform_var_file_path,
            terraform_var_file_name: terraform_var_file_name,
            phase: phase
          )
        end

        def resolved_rails_master_key
          from_env = ENV["RAILS_MASTER_KEY"].to_s.strip
          return from_env unless from_env.empty?

          backend = Workspace.repositories.find { |item| item["purpose"].to_s == "backend-api" }
          backend_path = backend && backend["path"]
          path_candidates = []
          path_candidates << File.join(Workspace::ROOT, backend_path, "config", "master.key") if backend_path
          path_candidates << File.join(Workspace::ROOT, "repos", "api-template", "config", "master.key")

          path_candidates.each do |path|
            next unless File.exist?(path)

            value = File.read(path).to_s.strip
            return value unless value.empty?
          end

          nil
        rescue Errno::EACCES
          nil
        end

        def required_runtime_output_keys(tfvars)
          keys = %w[app_id app_live_url project_id project_name]
          keys << "database_url" if tfvars["enable_postgres"] == true
          keys << "opensearch_url" if tfvars["enable_opensearch"] == true

          if tfvars["enable_spaces"] == true
            keys.concat(%w[spaces_bucket s3_endpoint aws_access_key_id aws_secret_access_key])
          end

          keys
        end

        def runtime_outputs
          return @runtime_outputs if defined?(@runtime_outputs)

          @runtime_outputs = terraform_runner.output_values!
        rescue SystemExit
          @runtime_outputs = nil
        end

        def blank_or_placeholder?(value)
          text = value.to_s.strip
          return true if text.empty?

          placeholder_patterns.any? { |pattern| pattern.match?(text) }
        end

        def placeholder_patterns
          @placeholder_patterns ||= ProjectStructureDoctorCommand::PLACEHOLDER_PATTERNS
        end

        def normalize_phase(value)
          normalized = value.to_s.strip
          normalized = "config" if normalized.empty?

          return normalized if VALID_PHASES.include?(normalized)

          Workspace.abort_with_help(
            "Invalid infra doctor phase '#{value}'.",
            details: "Supported phases: #{VALID_PHASES.join(', ')}",
            fixes: [
              "Run: bin/infra doctor production --phase=config",
              "Run: bin/infra doctor production --phase=runtime"
            ]
          )
        end

      end
    end
  end
end