# frozen_string_literal: true

require_relative "../../../secrets/resolver"

module Workspace
  module Services
    module Infra
      module Doctor
        class BlobStorageCheck
          class AwsAuthCheck
            def call
              Workspace.info("blob storage provider aws_s3: checking CLI/auth readiness")

              return false unless aws_cli_available?

              _out, success = Workspace.capture("aws sts get-caller-identity")
              if success
                Workspace.ok("AWS auth: valid")
                return true
              end

              Workspace.fail("AWS auth: invalid (run: aws configure, then aws sts get-caller-identity)")
              false
            end

            private

            def aws_cli_available?
              return true if Workspace.command_exists?("aws")

              Workspace.fail("AWS CLI: missing (checked aws)")
              false
            end
          end

          def initialize(manifest_configuration:, environment:, secrets_resolver:)
            @manifest_configuration = manifest_configuration
            @environment = environment
            @secrets_resolver = secrets_resolver
          end

          def label
            "blob store readiness"
          end

          def call
            config = manifest_configuration.read(environment: environment)
            spaces_enabled = dig_value(config, "components", "spaces", fallback: true)
            return true unless spaces_enabled

            provider = config["blob_store_provider"].to_s.strip
            return true if provider.empty?

            return AwsAuthCheck.new.call if provider == "aws_s3"
            return spaces_credentials_ready? if provider == "digitalocean_spaces"

            Workspace.ok("blob storage provider '#{provider}': selected")
            true
          end

          private

          attr_reader :manifest_configuration, :environment, :secrets_resolver

          def spaces_credentials_ready?
            access_key_id = secrets_resolver.spaces_access_key_id(interactive: false).to_s.strip
            secret_access_key = secrets_resolver.spaces_secret_access_key(interactive: false).to_s.strip

            missing = []
            missing << Workspace::Secrets::Resolver::SPACES_ACCESS_KEY_ID_WORKSPACE_KEY if access_key_id.empty?
            missing << Workspace::Secrets::Resolver::SPACES_SECRET_ACCESS_KEY_WORKSPACE_KEY if secret_access_key.empty?

            if missing.empty?
              Workspace.ok("blob storage provider 'digitalocean_spaces': credentials available")
              return true
            end

            Workspace.fail("blob storage provider 'digitalocean_spaces': missing #{missing.join(' and ')} in workspace credentials")
            false
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
end
