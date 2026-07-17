# frozen_string_literal: true

require "io/console"
require "tty-prompt"
require_relative "factory"

module Workspace
  module Secrets
    class Resolver
      DIGITALOCEAN_TOKEN_KEY = "DIGITALOCEAN_ACCESS_TOKEN"
      SPACES_ACCESS_KEY_ID_WORKSPACE_KEY = "TEST_SPACES_ACCESS_KEY_ID"
      SPACES_SECRET_ACCESS_KEY_WORKSPACE_KEY = "TEST_SPACES_SECRET_ACCESS_KEY"

      def initialize(stdout: $stdout, stdin: $stdin, workspace_adapter: nil, prompt: nil)
        @stdout = stdout
        @stdin = stdin
        @workspace_adapter = workspace_adapter || Factory.workspace_credentials_adapter
        @prompt = prompt || TTY::Prompt.new(input: @stdin, output: @stdout)
      end

      def digitalocean_token(interactive: true)
        workspace_token = workspace_adapter.read(DIGITALOCEAN_TOKEN_KEY).to_s.strip if workspace_adapter.available?
        if present?(workspace_token)
          return workspace_token unless interactive && interactive_input?

          return resolve_existing_token(token: workspace_token)
        end

        return nil unless interactive && interactive_input?

        token = prompt_token
        return nil unless present?(token)

        persist_workspace_token(token)
        token
      end

      def spaces_access_key_id(interactive: true)
        resolve_secret(
          key: SPACES_ACCESS_KEY_ID_WORKSPACE_KEY,
          interactive: interactive,
          prompt_label: "DigitalOcean Spaces access key ID",
          mask: false,
          include_env: false
        )
      end

      def spaces_secret_access_key(interactive: true)
        resolve_secret(
          key: SPACES_SECRET_ACCESS_KEY_WORKSPACE_KEY,
          interactive: interactive,
          prompt_label: "DigitalOcean Spaces secret access key",
          mask: true,
          include_env: false
        )
      end

      def persist_spaces_credentials(access_key_id:, secret_access_key:)
        access_saved = persist_workspace_value(key: SPACES_ACCESS_KEY_ID_WORKSPACE_KEY, value: access_key_id)
        secret_saved = persist_workspace_value(key: SPACES_SECRET_ACCESS_KEY_WORKSPACE_KEY, value: secret_access_key)
        access_saved && secret_saved
      end

      private

      attr_reader :stdin, :stdout, :workspace_adapter, :prompt

      def resolve_existing_token(token:)
        use_existing = prompt.yes?("Use existing DigitalOcean access token from workspace credentials?", default: true)
        selected_token = use_existing ? token : prompt_token

        return nil unless present?(selected_token)

        persist_workspace_token(selected_token)
        selected_token
      end

      def prompt_token
        token = prompt.mask("DigitalOcean access token").to_s.strip
        token.empty? ? nil : token
      end

      def persist_workspace_token(token)
        if workspace_adapter.available? && workspace_adapter.writable? && workspace_adapter.write(DIGITALOCEAN_TOKEN_KEY, token)
          prompt.say("Saved DIGITALOCEAN_ACCESS_TOKEN to workspace credentials.")
        else
          prompt.say("Unable to save token to workspace credentials. Run: bin/workspace credentials init")
        end
      end

      def resolve_secret(key:, interactive:, prompt_label:, mask:, include_env:)
        workspace_value = workspace_adapter.read(key).to_s.strip if workspace_adapter.available?
        return workspace_value if present?(workspace_value)

        if include_env
          env_value = ENV.fetch(key, "").to_s.strip
          return env_value if present?(env_value)
        end

        return nil unless interactive && interactive_input?

        value = if mask
                  prompt.mask(prompt_label).to_s.strip
                else
                  prompt.ask(prompt_label).to_s.strip
                end
        return nil unless present?(value)

        persist_workspace_value(key: key, value: value)
        value
      end

      def persist_workspace_value(key:, value:)
        if workspace_adapter.available? && workspace_adapter.writable? && workspace_adapter.write(key, value)
          prompt.say("Saved #{key} to workspace credentials.")
          true
        else
          prompt.say("Unable to save #{key} to workspace credentials. Run: bin/workspace credentials init")
          false
        end
      end

      def present?(value)
        !value.to_s.strip.empty?
      end

      def interactive_input?
        stdin.respond_to?(:tty?) && stdin.tty?
      end
    end
  end
end