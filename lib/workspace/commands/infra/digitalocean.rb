# frozen_string_literal: true

require_relative "../../../workspace"
require_relative "digitalocean_resources_command"
require_relative "digitalocean_purge_command"

module Workspace
  module Commands
    class Infra
      # Dispatches DigitalOcean-specific infra subcommands.
      class Digitalocean
        SUBCOMMANDS = {
          "resources" => Workspace::Commands::Infra::DigitaloceanResourcesCommand,
          "purge" => Workspace::Commands::Infra::DigitaloceanPurgeCommand
        }.freeze

        def initialize(argv, stdin: $stdin, stdout: $stdout, stderr: $stderr)
          @argv = argv.dup
          @stdin = stdin
          @stdout = stdout
          @stderr = stderr
        end

        def call
          subcommand_name = argv.shift
          subcommand = SUBCOMMANDS[subcommand_name]
          return usage unless subcommand

          subcommand.new(argv, stdin: stdin, stdout: stdout, stderr: stderr).call
        end

        private

        attr_reader :argv, :stdin, :stdout, :stderr

        def usage
          stderr.puts("Usage: bin/workspace infra digitalocean <resources|purge> [options]")
          1
        end
      end
    end
  end
end
