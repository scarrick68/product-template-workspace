#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "shellwords"
require "yaml"
require_relative "../../../workspace"
require_relative "tooling_checks"
require_relative "resource_availability"

module Workspace
  module Commands
    module Infra
      class SpacesBootstrapper
        SPACES_ACCESS_KEY_ID_KEY = "SPACES_ACCESS_KEY_ID"
        SPACES_SECRET_ACCESS_KEY_KEY = "SPACES_SECRET_ACCESS_KEY"

        def initialize(terraform_var_file_name:, tooling_checks: nil, config_file: File.join(Workspace::ROOT, "config", "infra.yml"))
          @terraform_var_file_name = terraform_var_file_name
          @tooling_checks = tooling_checks || ToolingChecks.new
          @config_file = config_file
        end

        def bootstrap!(tfvars:, write_tfvars:, reason_action: nil)
          availability = ResourceAvailability.from_infra_config(
            existing_infra_config,
            overrides: {
              blob_store_enabled: tfvars["enable_spaces"],
              blob_store_provider: tfvars["spaces_provider"]
            }
          )

          unless availability.managed_digitalocean_blob_store_enabled?
            Workspace.info("Skipping Spaces bootstrap: managed spaces are not enabled in #{terraform_var_file_name}")
            return :skipped
          end

          if spaces_credentials_present_in?(tfvars)
            Workspace.ok("Spaces credentials already present in #{terraform_var_file_name}")
            return :already_present
          end

          unless reason_action.nil?
            Workspace.info("Managed Spaces enabled and credentials are missing; bootstrapping now before infra #{reason_action}")
          end

          create_and_persist_spaces_credentials!(tfvars: tfvars, write_tfvars: write_tfvars)
          Workspace.ok("Spaces bootstrap credentials generated and persisted")
          :created
        end

        private

        attr_reader :terraform_var_file_name, :tooling_checks, :config_file

        def existing_infra_config
          return {} unless File.exist?(config_file)

          parsed = YAML.safe_load(File.read(config_file), permitted_classes: [], aliases: false)
          parsed.is_a?(Hash) ? parsed : {}
        rescue Psych::SyntaxError
          {}
        end

        def create_and_persist_spaces_credentials!(tfvars:, write_tfvars:)
          tooling_checks.digital_ocean_cli_available?
          tooling_checks.digital_ocean_auth_valid?

          bucket_name = resolved_bucket_name(tfvars["app_name"], tfvars["environment"], tfvars["data_artifact_bucket"])
          key_name = spaces_bootstrap_key_name(tfvars)
          command = [
            "doctl",
            "spaces",
            "keys",
            "create",
            key_name,
            "--grants",
            "bucket=#{bucket_name};permission=fullaccess",
            "-o",
            "json"
          ].map { |item| Shellwords.escape(item) }.join(" ")

          output, success = Workspace.capture(command)
          unless success
            Workspace.abort_with_help(
              "Unable to create Spaces access key via doctl.",
              details: redacted_output(output),
              fixes: [
                "Run: doctl spaces keys create #{key_name} --grants 'bucket=;permission=fullaccess' -o json",
                "(Or scope access to a single bucket) doctl spaces keys create #{key_name} --grants 'bucket=#{bucket_name};permission=fullaccess' -o json",
                "Ensure your DigitalOcean account has permission to manage Spaces keys.",
                "Re-run: bin/infra bootstrap-spaces"
              ]
            )
          end

          parsed = JSON.parse(output)
          key_data = parsed.is_a?(Array) ? parsed.first : parsed
          access_key = key_data && key_data["access_key"].to_s.strip
          secret_key = key_data && key_data["secret_key"].to_s.strip

          if access_key.empty? || secret_key.empty?
            Workspace.abort_with_help(
              "doctl did not return usable Spaces credentials.",
              details: redacted_output(output),
              fixes: [
                "Run the doctl command manually and confirm the output includes access_key and secret_key.",
                "Re-run: bin/infra bootstrap-spaces"
              ]
            )
          end

          persist_spaces_credentials!(
            tfvars: tfvars,
            access_key: access_key,
            secret_key: secret_key,
            write_tfvars: write_tfvars
          )
        rescue JSON::ParserError
          Workspace.abort_with_help(
            "Unable to parse doctl Spaces key output.",
            details: "Expected JSON output from doctl.",
            fixes: [
              "Run: doctl spaces keys create #{key_name} --grants 'bucket=;permission=fullaccess' -o json",
              "(Or scope access to a single bucket) doctl spaces keys create #{key_name} --grants 'bucket=#{bucket_name};permission=fullaccess' -o json",
              "Retry: bin/infra bootstrap-spaces"
            ]
          )
        end

        def persist_spaces_credentials!(tfvars:, access_key:, secret_key:, write_tfvars:)
          ENV[SPACES_ACCESS_KEY_ID_KEY] = access_key
          ENV[SPACES_SECRET_ACCESS_KEY_KEY] = secret_key

          tfvars["spaces_access_key_id"] = access_key
          tfvars["spaces_secret_access_key"] = secret_key
          tfvars["aws_access_key_id"] = access_key if tfvars["aws_access_key_id"].to_s.strip.empty?
          tfvars["aws_secret_access_key"] = secret_key if tfvars["aws_secret_access_key"].to_s.strip.empty?
          tfvars["data_artifact_bucket"] = resolved_bucket_name(tfvars["app_name"], tfvars["environment"], tfvars["data_artifact_bucket"])
          tfvars["s3_endpoint"] = resolved_spaces_endpoint(tfvars["do_region"])

          write_tfvars.call(tfvars)
        end

        def spaces_credentials_present_in?(tfvars)
          access_key = tfvars["spaces_access_key_id"].to_s.strip
          secret_key = tfvars["spaces_secret_access_key"].to_s.strip
          !access_key.empty? && !secret_key.empty?
        end

        def spaces_bootstrap_key_name(tfvars)
          bucket = resolved_bucket_name(tfvars["app_name"], tfvars["environment"], tfvars["data_artifact_bucket"])
          "#{bucket}-bootstrap-#{Time.now.to_i}".gsub(/[^a-zA-Z0-9\-]/, "-")
        end

        def resolved_bucket_name(app_name, environment, configured_bucket)
          bucket = configured_bucket.to_s.strip
          return bucket unless bucket.empty?

          slug = "#{app_name}-#{environment}-artifacts"
          slug.downcase.gsub("_", "-")[0, 63]
        end

        def resolved_spaces_endpoint(do_region)
          region = do_region.to_s.strip
          region = "nyc3" if region.empty?
          "https://#{region}.digitaloceanspaces.com"
        end

        def redacted_output(text)
          sanitized = text.to_s
            .gsub(/("?(secret_key|access_key|secret_access_key|access_key_id)"?\s*[:=]\s*)("[^"]+"|\S+)/i, '\\1[REDACTED]')
            .gsub(/(AWS_SECRET_ACCESS_KEY|AWS_ACCESS_KEY_ID|DO_API_TOKEN|DIGITALOCEAN_ACCESS_TOKEN)=\S+/i, '\\1=[REDACTED]')
            .strip

          return "No command output captured." if sanitized.empty?

          sanitized
        end

      end
    end
  end
end