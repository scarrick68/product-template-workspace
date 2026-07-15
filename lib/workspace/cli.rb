# frozen_string_literal: true

require_relative "../workspace"
require_relative "context"
require_relative "commands/new_project"
require_relative "commands/credentials"
require_relative "commands/repository"
require_relative "commands/infra"

module Workspace
  module CLI
    class Runner
      COMMANDS = {
        "new-project" => Workspace::Commands::NewProject,
        "credentials" => Workspace::Commands::Credentials,
        "repository" => Workspace::Commands::Repository,
        "infra" => Workspace::Commands::Infra
      }.freeze

      def initialize(argv, stdin: $stdin, stdout: $stdout, stderr: $stderr)
        @argv = argv.dup
        @stdin = stdin
        @stdout = stdout
        @stderr = stderr
      end

      def call
        command_name = argv.shift
        return usage unless command_name

        command_class = COMMANDS[command_name]

        return usage(command_name) unless command_class

        command_class.new(argv, stdin: stdin, stdout: stdout, stderr: stderr).call
      end

      private

      attr_reader :argv, :stdin, :stdout, :stderr

      def usage(command_name = nil)
        if command_name
          stderr.puts("Unknown command: #{command_name}")

          suggestion = suggested_command_for(command_name)
          stderr.puts("Did you mean: #{suggestion}?") if suggestion
        end

        stderr.puts("Usage: bin/workspace <command> [options]")
        stderr.puts("Commands: new-project, credentials, repository, infra")
        1
      end

      def suggested_command_for(command_name)
        underscore_variant = command_name.tr("_", "-")
        return underscore_variant if COMMANDS.key?(underscore_variant)

        COMMANDS.keys.find { |candidate| candidate.start_with?(command_name) }
      end
    end
  end
end
