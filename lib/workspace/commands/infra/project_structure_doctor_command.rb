#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "yaml"
require_relative "../../../workspace"

module Workspace
  module Commands
    module Infra
      class ProjectStructureDoctorCommand
        VALID_PHASES = %w[config runtime].freeze

        ESSENTIAL_INFRA_CONFIG_KEYS = %w[
          app_name
          environment
          region
          do_region
          project
          spaces_provider
          components
          github
        ].freeze

        ESSENTIAL_PROJECT_KEYS = %w[
          name
          environment
          purpose
        ].freeze

        ESSENTIAL_COMPONENT_KEYS = %w[
          api
          worker
          web
          postgres
          opensearch
          spaces
        ].freeze

        ESSENTIAL_GITHUB_KEYS = %w[
          owner
          api_repo
          web_repo
          branch
        ].freeze

        ESSENTIAL_TFVARS_KEYS = %w[
          app_name
          environment
          region
          do_region
          project_name
          project_environment
          project_purpose
          digitalocean_access_token
          enable_spaces
          spaces_provider
          github_owner
          api_repo
          web_repo
          branch
        ].freeze

        PLACEHOLDER_PATTERNS = [
          /\A<.*>\z/,
          /\Achange-me\z/i,
          /\Achangeme\z/i,
          /\Aexample\z/i,
          /\Atodo\z/i,
          /\Aplaceholder\z/i,
          /\Aset-.+\z/i
        ].freeze

        SENSITIVE_TFVARS_KEYS = %w[
          digitalocean_access_token
          database_url
          opensearch_url
        ].freeze

        def initialize(config_file:, terraform_var_file_path:, terraform_var_file_name:, phase: "config")
          @config_file = config_file
          @terraform_var_file_path = terraform_var_file_path
          @terraform_var_file_name = terraform_var_file_name
          @phase = normalize_phase(phase)
        end

        def call
          check_infra_config && check_terraform_vars
        end

        private

        attr_reader :config_file, :terraform_var_file_path, :terraform_var_file_name, :phase

        def check_infra_config
          config = parse_yaml_hash(config_file, label: "infra config")
          return false unless config
          return false unless validate_required_keys(config, ESSENTIAL_INFRA_CONFIG_KEYS, "infra config", relative_path(config_file))

          components = hash_or_empty(config["components"])
          return false unless validate_required_keys(components, ESSENTIAL_COMPONENT_KEYS, "infra config", "components")

          github = hash_or_empty(config["github"])
          return false unless validate_required_keys(github, ESSENTIAL_GITHUB_KEYS, "infra config", "github")

          project = hash_or_empty(config["project"])
          return false unless validate_required_keys(project, ESSENTIAL_PROJECT_KEYS, "infra config", "project")

          pass("infra config", "essential structure present")
        end

        def check_terraform_vars
          tfvars = parse_json_hash(terraform_var_file_path, label: "terraform vars")
          return false unless tfvars
          return false unless validate_required_keys(tfvars, ESSENTIAL_TFVARS_KEYS, "terraform vars", terraform_var_file_name)
          return false unless validate_sensitive_values(tfvars)

          pass("terraform vars", "essential structure present")
        end

        def missing_keys(hash, keys)
          keys.reject { |key| hash.key?(key) }
        end

        def hash_or_empty(value)
          value.is_a?(Hash) ? value : {}
        end

        def validate_required_keys(hash, required_keys, scope, location)
          missing = missing_keys(hash, required_keys)
          return true if missing.empty?

          fail_check(scope, "missing keys #{missing.join(', ')} in #{location}")
        end

        def validate_sensitive_values(tfvars)
          return true if phase == "config"

          invalid = []

          SENSITIVE_TFVARS_KEYS.each do |key|
            next unless tfvars.key?(key)
            next unless placeholder_like?(tfvars[key])

            invalid << key
          end

          if requires_external_aws_credentials?(tfvars)
            %w[aws_access_key_id aws_secret_access_key].each do |key|
              invalid << key if placeholder_like?(tfvars[key])
            end
          end

          invalid.uniq!
          return true if invalid.empty?

          fail_check("terraform vars", "sensitive values look unset/placeholders for keys: #{invalid.join(', ')}")
        end

        def requires_external_aws_credentials?(tfvars)
          return false unless tfvars["enable_spaces"] == true
          return true if tfvars["spaces_provider"].to_s == "aws_s3"

          tfvars["spaces_create_key"] == false
        end

        def normalize_phase(value)
          normalized = value.to_s.strip
          normalized = "config" if normalized.empty?
          return normalized if VALID_PHASES.include?(normalized)

          Workspace.abort_with_help(
            "Invalid project structure doctor phase '#{value}'.",
            details: "Supported phases: #{VALID_PHASES.join(', ')}",
            fixes: [
              "Use phase=config for pre-apply checks.",
              "Use phase=runtime for post-apply checks."
            ]
          )
        end

        def placeholder_like?(value)
          text = value.to_s.strip
          return true if text.empty?

          PLACEHOLDER_PATTERNS.any? { |pattern| pattern.match?(text) }
        end

        def parse_yaml_hash(path, label:)
          return fail_check(label, "missing #{relative_path(path)}") unless File.exist?(path)

          parsed = YAML.safe_load(File.read(path), permitted_classes: [], aliases: false)
          return parsed if parsed.is_a?(Hash)

          fail_check(label, "expected top-level object in #{relative_path(path)}")
        rescue Psych::SyntaxError
          fail_check(label, "invalid YAML in #{relative_path(path)}")
        end

        def parse_json_hash(path, label:)
          return fail_check(label, "missing #{relative_path(path)}") unless File.exist?(path)

          parsed = JSON.parse(File.read(path))
          return parsed if parsed.is_a?(Hash)

          fail_check(label, "expected top-level object in #{relative_path(path)}")
        rescue JSON::ParserError
          fail_check(label, "invalid JSON in #{relative_path(path)}")
        end

        def pass(scope, message)
          Workspace.ok("#{scope}: #{message}")
          true
        end

        def fail_check(scope, message)
          Workspace.fail("#{scope}: #{message}")
          false
        end

        def relative_path(path)
          path.to_s.sub("#{Workspace::ROOT}/", "")
        end
      end
    end
  end
end