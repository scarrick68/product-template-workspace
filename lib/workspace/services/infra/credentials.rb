# frozen_string_literal: true

module Workspace
  module Services
    module Infra
      # Infra-facing adapter for provider credentials used by Terraform and doctor checks.
      class Credentials
        DIGITALOCEAN_TOKEN_ENV_KEY = "DIGITALOCEAN_ACCESS_TOKEN"

        def initialize(secrets_resolver:)
          @secrets_resolver = secrets_resolver
        end

        def digitalocean_token(interactive:)
          secrets_resolver.digitalocean_token(interactive: interactive).to_s.strip
        end

        def digitalocean_token_available?
          !digitalocean_token(interactive: false).empty?
        end

        def export_terraform_environment!(interactive:)
          token = digitalocean_token(interactive: interactive)
          return false if token.empty?

          ENV[DIGITALOCEAN_TOKEN_ENV_KEY] = token
          true
        end

        def digitalocean_token_env_key
          DIGITALOCEAN_TOKEN_ENV_KEY
        end

        private

        attr_reader :secrets_resolver
      end
    end
  end
end
