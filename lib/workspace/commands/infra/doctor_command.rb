#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "yaml"
require_relative "../../../workspace"
require_relative "../../../workspace/secrets/resolver"
require_relative "tooling_checks"
require_relative "resource_availability"
require_relative "project_structure_doctor_command"

module Workspace
  module Commands
    module Infra
      class DoctorCommand
        DIGITALOCEAN_TOKEN_KEY = "DIGITALOCEAN_ACCESS_TOKEN"

        def initialize(config_file:, terraform_var_file_path:, terraform_var_file_name:, secrets_resolver: nil, tooling_checks: nil, stdin: $stdin, stdout: $stdout)
          @config_file = config_file
          @terraform_var_file_path = terraform_var_file_path
          @terraform_var_file_name = terraform_var_file_name
          @stdin = stdin
          @stdout = stdout
          @secrets_resolver = secrets_resolver || Workspace::Secrets::Resolver.new(io: @stdout, input: @stdin)
          @tooling_checks = tooling_checks || ToolingChecks.new
        end

        def call
          checks = [
            ["Terraform/OpenTofu CLI", -> { check_terraform_or_open_tofu_cli_available }],
            ["doctl CLI", -> { tooling_checks.digital_ocean_cli_available? }],
            ["GitHub CLI", -> { tooling_checks.github_cli_available? }],
            ["git CLI", -> { tooling_checks.git_cli_available? }],
            [DIGITALOCEAN_TOKEN_KEY, -> { check_digitalocean_access_token }],
            ["doctl auth", -> { tooling_checks.digital_ocean_auth_valid? }],
            ["gh auth", -> { tooling_checks.github_auth_valid? }],
            ["project structure", -> { project_structure_doctor.call }],
            ["expected repositories", -> { check_expected_repositories }],
            ["blob store readiness", -> { check_blob_store_readiness }]
          ]

          failed_checks = []
          checks.each do |label, check|
            failed_checks << label unless check.call
          end

          unless failed_checks.empty?
            Workspace.info("infra doctor failed checks: #{failed_checks.join(', ')}")
            Workspace.fail("infra doctor detected one or more issues")
            return 1
          end

          Workspace.ok("infra doctor checks passed")
          0
        end

        private

        attr_reader :config_file, :terraform_var_file_path, :terraform_var_file_name, :stdin, :stdout, :secrets_resolver, :tooling_checks

        def check_digitalocean_access_token
          token = ensure_digitalocean_access_token(interactive: false)
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

        def check_blob_store_readiness
          config = existing_infra_config
          availability = ResourceAvailability.from_infra_config(config)
          return true unless availability.blob_store_enabled?

          provider = availability.blob_store_provider
          return true if provider.to_s.empty?

          if provider == "aws_s3"
            return check_aws_s3_readiness
          end

          if provider == "digitalocean_spaces"
            return check_digitalocean_spaces_readiness
          end

          Workspace.fail("blob storage provider '#{provider}': unsupported (expected digitalocean_spaces or aws_s3)")
          false
        end

        def check_digitalocean_spaces_readiness
          tfvars = terraform_var_file_values
          should_create_bucket = tfvars.fetch("spaces_create_bucket", true)
          should_create_key = tfvars.fetch("spaces_create_key", true)

          unless should_create_bucket || should_create_key
            Workspace.ok("DigitalOcean Spaces provisioning: disabled")
            return true
          end

          access_key = tfvars["spaces_access_key_id"].to_s.strip
          secret_key = tfvars["spaces_secret_access_key"].to_s.strip

          if access_key.empty? || secret_key.empty?
            Workspace.fail("DigitalOcean Spaces credentials: missing in #{terraform_var_file_name} (spaces_access_key_id/spaces_secret_access_key)")
            return false
          end

          Workspace.ok("DigitalOcean Spaces credentials: present")
          true
        end

        def check_aws_s3_readiness
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

        def ensure_digitalocean_access_token(interactive:)
          token = secrets_resolver.digitalocean_token(interactive: interactive)
          return nil if token.nil? || token.empty?

          ENV[DIGITALOCEAN_TOKEN_KEY] = token
          token
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
            terraform_var_file_name: terraform_var_file_name
          )
        end

      end
    end
  end
end