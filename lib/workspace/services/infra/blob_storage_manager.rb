# frozen_string_literal: true

require "shellwords"
require "json"
require_relative "../../secrets/resolver"

module Workspace
  module Services
    module Infra
      class BlobStorageManager
        SPACES_ACCESS_KEY_ID_ENV_KEY = "SPACES_ACCESS_KEY_ID"
        SPACES_SECRET_ACCESS_KEY_ENV_KEY = "SPACES_SECRET_ACCESS_KEY"
        SPACES_ACCESS_KEY_ID_WORKSPACE_KEY = Workspace::Secrets::Resolver::SPACES_ACCESS_KEY_ID_WORKSPACE_KEY
        SPACES_SECRET_ACCESS_KEY_WORKSPACE_KEY = Workspace::Secrets::Resolver::SPACES_SECRET_ACCESS_KEY_WORKSPACE_KEY

        def initialize(manifest_configuration:, secrets_resolver:, stdin:)
          @manifest_configuration = manifest_configuration
          @secrets_resolver = secrets_resolver
          @stdin = stdin
        end

        def ensure_spaces_credentials_for_provisioning(environment:, interactive:)
          config = manifest_configuration.read(environment: environment)
          spaces_enabled = dig_value(config, "components", "spaces", fallback: true)
          return nil unless spaces_enabled

          provider = config["blob_store_provider"].to_s.strip
          return nil unless provider == "digitalocean_spaces"

          # Spaces credentials are workspace-managed and should be auto-provisioned via doctl when missing.
          access_key_id = secrets_resolver.spaces_access_key_id(interactive: false).to_s.strip
          secret_access_key = secrets_resolver.spaces_secret_access_key(interactive: false).to_s.strip

          missing = []
          missing << SPACES_ACCESS_KEY_ID_WORKSPACE_KEY if access_key_id.empty?
          missing << SPACES_SECRET_ACCESS_KEY_WORKSPACE_KEY if secret_access_key.empty?
          return export_spaces_credentials(access_key_id, secret_access_key) if missing.empty?

          Workspace.info("DigitalOcean Spaces credentials missing (#{missing.join(' and ')}); provisioning via doctl")
          provisioned_access_key_id, provisioned_secret_access_key = provision_spaces_credentials!(config)

          persist_ok = secrets_resolver.persist_spaces_credentials(
            access_key_id: provisioned_access_key_id,
            secret_access_key: provisioned_secret_access_key
          )
          unless persist_ok
            Workspace.abort_with_help(
              "Unable to persist provisioned DigitalOcean Spaces credentials.",
              details: "Workspace encrypted credentials are unavailable or not writable.",
              fixes: [
                "Run: bin/workspace credentials init",
                "Re-run infra plan/apply after credentials files are initialized"
              ]
            )
          end

          export_spaces_credentials(provisioned_access_key_id, provisioned_secret_access_key)
        end

        private

        attr_reader :manifest_configuration, :secrets_resolver, :stdin

        def provision_spaces_credentials!(config)
          key_name = generated_spaces_key_name(config)
          grants = Shellwords.escape("permission=fullaccess")
          command = "doctl spaces keys create #{Shellwords.escape(key_name)} --grants #{grants} --output json"
          output, success = Workspace.capture(command)

          unless success
            Workspace.abort_with_help(
              "Failed to provision DigitalOcean Spaces credentials via doctl.",
              details: output.to_s.strip.empty? ? "doctl spaces keys create failed" : output.to_s.strip,
              fixes: [
                "Re-run: #{command}",
                "Run: doctl spaces keys list to inspect existing keys"
              ]
            )
          end

          parsed = parse_json_spaces_credentials(output)
          return parsed if parsed

          Workspace.abort_with_help(
            "Failed to parse provisioned DigitalOcean Spaces credentials.",
            details: "Unexpected doctl output format while creating Spaces key.",
            fixes: [
              "Run: #{command}",
              "Ensure doctl is up to date and rerun infra doctor"
            ]
          )
        end

        def parse_json_spaces_credentials(output)
          parsed = JSON.parse(output.to_s)
          row = parsed.is_a?(Array) ? parsed.first : parsed
          return nil unless row.is_a?(Hash)

          access_key_id = row["access_key"].to_s.strip
          access_key_id = row["accessKey"].to_s.strip if access_key_id.empty?
          secret_access_key = row["secret_key"].to_s.strip
          secret_access_key = row["secretKey"].to_s.strip if secret_access_key.empty?
          return nil if access_key_id.empty? || secret_access_key.empty?

          [access_key_id, secret_access_key]
        rescue JSON::ParserError
          nil
        end

        def generated_spaces_key_name(config)
          app_name = config.fetch("app_name", "workspace").to_s.downcase
          sanitized_app_name = app_name.gsub(/[^a-z0-9-]/, "-").gsub(/-+/, "-").gsub(/\A-|-\z/, "")
          normalized_app_name = sanitized_app_name.empty? ? "workspace" : sanitized_app_name

          "workspace-#{normalized_app_name}-#{Time.now.to_i}"
        end

        def export_spaces_credentials(access_key_id, secret_access_key)
          ENV[SPACES_ACCESS_KEY_ID_ENV_KEY] = access_key_id
          ENV[SPACES_SECRET_ACCESS_KEY_ENV_KEY] = secret_access_key
          true
        end

        def dig_value(hash, *keys, fallback: nil)
          value = keys.reduce(hash) do |memo, key|
            break nil unless memo.is_a?(Hash)

            memo[key]
          end
          value.nil? ? fallback : value
        end
      end
    end
  end
end
