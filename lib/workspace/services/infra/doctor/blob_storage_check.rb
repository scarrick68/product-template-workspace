# frozen_string_literal: true

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

          def initialize(manifest_configuration:, environment:)
            @manifest_configuration = manifest_configuration
            @environment = environment
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

            Workspace.ok("blob storage provider '#{provider}': selected")
            true
          end

          private

          attr_reader :manifest_configuration, :environment

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
