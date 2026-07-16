# frozen_string_literal: true

module Workspace
  module Services
    module Infra
      module Doctor
        class ProviderAuthenticationChecks
          class DigitaloceanTokenCheck
            def initialize(credentials:)
              @credentials = credentials
            end

            def label
              credentials.digitalocean_token_env_key
            end

            def call
              unless credentials.digitalocean_token_available?
                Workspace.fail("#{credentials.digitalocean_token_env_key}: missing")
                return false
              end

              credentials.export_terraform_environment!(interactive: false)
              Workspace.ok("#{credentials.digitalocean_token_env_key}: available")
              true
            end

            private

            attr_reader :credentials
          end

          class DoctlAuthCheck
            def label
              "doctl auth"
            end

            def call
              return true unless Workspace.command_exists?("doctl")

              _out, success = Workspace.capture("doctl account get")
              if success
                Workspace.ok("doctl auth: valid")
                return true
              end

              Workspace.fail("doctl auth: invalid (run: doctl auth init)")
              false
            end
          end

          class GhAuthCheck
            def label
              "gh auth"
            end

            def call
              return true unless Workspace.command_exists?("gh")

              _out, success = Workspace.capture("gh auth status")
              if success
                Workspace.ok("gh auth: valid")
                return true
              end

              Workspace.fail("gh auth: invalid (run: gh auth login)")
              false
            end
          end

          def initialize(credentials:)
            @credentials = credentials
          end

          def to_a
            [
              DigitaloceanTokenCheck.new(
                credentials: credentials
              ),
              DoctlAuthCheck.new,
              GhAuthCheck.new
            ]
          end

          private

          attr_reader :credentials
        end
      end
    end
  end
end
