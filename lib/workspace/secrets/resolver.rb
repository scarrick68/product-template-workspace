# frozen_string_literal: true

require "io/console"
require "tty-prompt"
require_relative "factory"
require_relative "store"

module Workspace
  module Secrets
    class Resolver
      DIGITALOCEAN_TOKEN_KEY = "DIGITALOCEAN_ACCESS_TOKEN"

      def initialize(io: $stdout, input: $stdin, store: nil, prompt: TTY::Prompt.new(input: @input, output: @io))
        @io = io
        @input = input
        @store = store || Store.new(
          env_adapter: Factory.env_adapter,
          keychain_adapter: Factory.keychain_adapter
        )
        @prompt = prompt
      end

      def digitalocean_token(interactive: true)
        result = store.read(DIGITALOCEAN_TOKEN_KEY)
        return result.value if present?(result.value)

        return nil unless interactive && interactive_input?

        warn_if_unsupported
        prompt_for_token
      end

      private

      attr_reader :io, :input, :store, :prompt

      def prompt_for_token
        io.puts("DigitalOcean access token not found.")
        io.puts("Choose how to continue:")
        io.puts("1. Use token for this run only")
        io.puts("2. Print env var instructions")
        io.puts("3. Store token in #{store.keychain_adapter.name}") if store.keychain_adapter.writable?

        allowed_choices = store.keychain_adapter.writable? ? %w[1 2 3] : %w[1 2]
        choice = prompt.ask("Selection", default: "1") do |q|
          q.in(allowed_choices)
        end

        case choice
        when "2"
          print_env_instructions
          nil
        when "3"
          if store.keychain_adapter.writable?
            token = prompt_token
            return nil unless present?(token)

            if store.write(DIGITALOCEAN_TOKEN_KEY, token)
              io.puts("Saved DIGITALOCEAN_ACCESS_TOKEN to #{store.keychain_adapter.name}.")
            else
              io.puts("Unable to save token to #{store.keychain_adapter.name}; using token for this run only.")
            end

            token
          else
            prompt_token
          end
        else
          prompt_token
        end
      end

      def prompt_token
        token = prompt.mask("DigitalOcean access token").to_s.strip
        token.empty? ? nil : token
      end

      def print_env_instructions
        io.puts("Run:")
        io.puts("export DIGITALOCEAN_ACCESS_TOKEN=your_token_here")
      end

      def warn_if_unsupported
        adapter = store.keychain_adapter
        return unless adapter.respond_to?(:warning)

        io.puts(adapter.warning)
      end

      def present?(value)
        !value.to_s.strip.empty?
      end

      def interactive_input?
        input.respond_to?(:tty?) && input.tty?
      end
    end
  end
end