#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
require "tmpdir"
require "shellwords"
require_relative "../../../workspace"
require_relative "resource_availability"

module Workspace
  module Commands
    module Infra
      class RailsBlobCredentialsSync
        # technically, it could be others. it just has to be S3 compatible for Rails Active Storage. 
        SUPPORTED_BLOB_PROVIDERS = %w[digitalocean_spaces aws_s3].freeze

        AMAZON_STORAGE_CONFIG = {
          "service" => "S3",
          "access_key_id" => "<%= Rails.application.credentials.dig(:aws, :access_key_id) %>",
          "secret_access_key" => "<%= Rails.application.credentials.dig(:aws, :secret_access_key) %>",
          "endpoint" => "<%= Rails.application.credentials.dig(:aws, :endpoint) %>",
          "region" => "<%= Rails.application.credentials.dig(:aws, :region) %>",
          "bucket" => "<%= Rails.application.credentials.dig(:aws, :bucket) %>"
        }.freeze

        PRODUCTION_STORAGE_TARGET = "config.active_storage.service = :local"
        PRODUCTION_STORAGE_REPLACEMENT = "config.active_storage.service = ENV.fetch(\"ACTIVE_STORAGE_SERVICE\", \"amazon\").to_sym"

        def initialize(workspace_root: Workspace::ROOT, config_file: File.join(Workspace::ROOT, "config", "infra.yml"))
          @workspace_root = workspace_root
          @config_file = config_file
        end

        def sync!(tfvars:, terraform_outputs: {})
          availability = ResourceAvailability.from_infra_config(
            existing_infra_config,
            overrides: {
              blob_store_enabled: tfvars["enable_spaces"],
              blob_store_provider: tfvars["spaces_provider"]
            }
          )
          return unless availability.blob_store_enabled?

          provider = availability.blob_store_provider
          return unless SUPPORTED_BLOB_PROVIDERS.include?(provider)

          access_key = effective_value(terraform_outputs, "aws_access_key_id", tfvars["aws_access_key_id"])
          secret_key = effective_value(terraform_outputs, "aws_secret_access_key", tfvars["aws_secret_access_key"])
          return if access_key.empty? || secret_key.empty?

          api_repo = Workspace.repositories.find { |item| item["purpose"].to_s == "backend-api" }
          return unless api_repo && api_repo["path"]

          api_root = File.join(workspace_root, api_repo["path"])
          return unless Dir.exist?(api_root)

          update_api_rails_credentials!(api_root, tfvars, terraform_outputs)
          update_api_storage_config!(api_root)
          update_api_production_storage_service!(api_root)
        end

        private

        attr_reader :workspace_root, :config_file

        def existing_infra_config
          return {} unless File.exist?(config_file)

          parsed = YAML.safe_load(File.read(config_file), permitted_classes: [], aliases: false)
          parsed.is_a?(Hash) ? parsed : {}
        rescue Psych::SyntaxError
          {}
        end

        def update_api_storage_config!(api_root)
          storage_path = File.join(api_root, "config", "storage.yml")
          return unless File.exist?(storage_path)

          config = read_yaml_hash(storage_path)
          return unless config.is_a?(Hash)
          return if config["amazon"] == AMAZON_STORAGE_CONFIG

          config["amazon"] = AMAZON_STORAGE_CONFIG
          write_yaml_hash(storage_path, config)
        end

        def update_api_production_storage_service!(api_root)
          production_path = File.join(api_root, "config", "environments", "production.rb")
          return unless File.exist?(production_path)

          content = File.read(production_path)
          return unless content.include?(PRODUCTION_STORAGE_TARGET)

          File.write(production_path, content.sub(PRODUCTION_STORAGE_TARGET, PRODUCTION_STORAGE_REPLACEMENT))
        end

        def update_api_rails_credentials!(api_root, tfvars, terraform_outputs)
          original_yaml = read_api_rails_credentials_yaml(api_root)
          credentials = parse_yaml_hash(original_yaml)
          credentials["aws"] = {} unless credentials["aws"].is_a?(Hash)
          credentials["aws"]["access_key_id"] = effective_value(terraform_outputs, "aws_access_key_id", tfvars["aws_access_key_id"])
          credentials["aws"]["secret_access_key"] = effective_value(terraform_outputs, "aws_secret_access_key", tfvars["aws_secret_access_key"])
          credentials["aws"]["endpoint"] = effective_value(terraform_outputs, "s3_endpoint", tfvars["s3_endpoint"])
          credentials["aws"]["region"] = tfvars["do_region"].to_s
          credentials["aws"]["bucket"] = effective_value(terraform_outputs, "spaces_bucket", tfvars["data_artifact_bucket"])

          write_api_rails_credentials(api_root, credentials, original_yaml: original_yaml)
        end

        def read_api_rails_credentials_yaml(api_root)
          output, success = Workspace.capture("bin/rails credentials:show", chdir: api_root)
          unless success
            Workspace.abort_with_help(
              "Unable to read Rails credentials from backend API repo.",
              details: "bin/rails credentials:show failed in #{api_root}.",
              fixes: [
                "Ensure #{api_root}/config/master.key exists.",
                "Run manually in API repo: bin/rails credentials:show",
                "Retry infra apply after fixing credentials access."
              ]
            )
          end

          output
        end

        def parse_yaml_hash(content)
          parsed = YAML.safe_load(content, permitted_classes: [], aliases: true)
          parsed.is_a?(Hash) ? parsed : {}
        rescue Psych::SyntaxError
          {}
        end

        def read_yaml_hash(path)
          parse_yaml_hash(File.read(path))
        rescue Errno::ENOENT
          {}
        end

        def write_yaml_hash(path, hash)
          File.write(path, hash.to_yaml)
        end

        def write_api_rails_credentials(api_root, credentials_hash, original_yaml:)
          yaml_content = credentials_hash.to_yaml

          # Rails credentials are encrypted; this temp dir provides the edited plaintext
          # and a backup of the previously decrypted content for local recovery.
          Dir.mktmpdir("infra-rails-creds") do |dir|
            source_path = File.join(dir, "credentials.yml")
            backup_path = File.join(dir, "credentials.backup.yml")
            editor_path = File.join(dir, "editor.sh")

            File.write(source_path, yaml_content)
            File.write(backup_path, original_yaml.to_s)
            # Restrict backup plaintext credentials to current user only.
            File.chmod(0o600, backup_path)
            # credentials:edit opens an editor with the decrypted file path as "$1".
            # This script replaces that buffer with our prepared YAML content.
            File.write(editor_path, "#!/usr/bin/env bash\ncat #{Shellwords.escape(source_path)} > \"$1\"\n")
            # Script must be executable for Rails to invoke it as EDITOR.
            File.chmod(0o755, editor_path)

            # Use Rails' own credentials command so encryption and key handling stay
            # inside Rails, instead of writing encrypted files directly.
            Workspace.run(
              "EDITOR=#{Shellwords.escape(editor_path)} bin/rails credentials:edit",
              chdir: api_root
            )
          end
        end

        def effective_value(outputs, output_key, fallback)
          from_output = outputs[output_key]
          value = from_output.nil? ? fallback : from_output
          value.to_s.strip
        end
      end
    end
  end
end