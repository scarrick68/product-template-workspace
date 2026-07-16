# frozen_string_literal: true

module Workspace
  module Services
    module Infra
      module Doctor
        class ProviderAuthenticationChecks
          class DigitaloceanTokenCheck
            def initialize(secrets_resolver:, digitalocean_token_key:)
              @secrets_resolver = secrets_resolver
              @digitalocean_token_key = digitalocean_token_key
            end

            def label
              digitalocean_token_key
            end

            def call
              token = secrets_resolver.digitalocean_token(interactive: false)
              if token.nil? || token.empty?
                Workspace.fail("#{digitalocean_token_key}: missing")
                return false
              end

              ENV[digitalocean_token_key] = token
              Workspace.ok("#{digitalocean_token_key}: available")
              true
            end

            private

            attr_reader :secrets_resolver, :digitalocean_token_key
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

          def initialize(secrets_resolver:, digitalocean_token_key:)
            @secrets_resolver = secrets_resolver
            @digitalocean_token_key = digitalocean_token_key
          end

          def to_a
            [
              DigitaloceanTokenCheck.new(
                secrets_resolver: secrets_resolver,
                digitalocean_token_key: digitalocean_token_key
              ),
              DoctlAuthCheck.new,
              GhAuthCheck.new
            ]
          end

          private

          attr_reader :secrets_resolver, :digitalocean_token_key
        end
      end
    end
  end
end
