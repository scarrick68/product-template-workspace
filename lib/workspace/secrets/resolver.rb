# frozen_string_literal: true

require "io/console"
require "tty-prompt"
require_relative "factory"

module Workspace
  module Secrets
    class Resolver
      DIGITALOCEAN_TOKEN_KEY = "DIGITALOCEAN_ACCESS_TOKEN"

      def initialize(stdout: $stdout, stdin: $stdin, workspace_adapter: nil, prompt: TTY::Prompt.new(input: @stdin, output: @stdout))
        @stdout = stdout
        @stdin = stdin
        @workspace_adapter = workspace_adapter || Factory.workspace_credentials_adapter
        @prompt = prompt
      end

      def digitalocean_token(interactive: true)
        workspace_token = workspace_adapter.read(DIGITALOCEAN_TOKEN_KEY).to_s.strip if workspace_adapter.available?
        if present?(workspace_token)
          return workspace_token unless interactive && interactive_input?

          return resolve_existing_token(token: workspace_token, source: workspace_adapter.name)
        end

        env_token = ENV.fetch(DIGITALOCEAN_TOKEN_KEY, "").to_s.strip
        if present?(env_token)
          return env_token unless interactive && interactive_input?

          return resolve_existing_token(token: env_token, source: "environment variable")
        end

        return nil unless interactive && interactive_input?

        prompt_for_token
      end

      private

      attr_reader :stdin, :stdout, :workspace_adapter, :prompt

      def resolve_existing_token(token:, source:)
        use_existing = prompt.yes?("Use existing DigitalOcean access token from #{source}?", default: true)
        selected_token = use_existing ? token : prompt_token

        return nil unless present?(selected_token)

        persist_workspace_token(selected_token)
        selected_token
      end

      def prompt_for_token
        choice = prompt.select(
          "DigitalOcean access token not found. Choose how to continue:",
          ["Provide token and save to workspace credentials", "Print env var instructions"],
          default: "Provide token and save to workspace credentials"
        )

        case choice
        when "Print env var instructions"
          print_env_instructions
          nil
        else
          token = prompt_token
          return nil unless present?(token)

          persist_workspace_token(token)
          token
        end
      end

      def prompt_token
        token = prompt.mask("DigitalOcean access token").to_s.strip
        token.empty? ? nil : token
      end

      def print_env_instructions
        prompt.say("Run:")
        prompt.say("export DIGITALOCEAN_ACCESS_TOKEN=your_token_here")
      end

      def persist_workspace_token(token)
        if workspace_adapter.available? && workspace_adapter.writable? && workspace_adapter.write(DIGITALOCEAN_TOKEN_KEY, token)
          prompt.say("Saved DIGITALOCEAN_ACCESS_TOKEN to workspace credentials.")
        else
          prompt.say("Unable to save token to workspace credentials. Run: bin/workspace credentials init")
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