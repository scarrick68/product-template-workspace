# frozen_string_literal: true

require_relative "../../workspace"
require_relative "../context"
require_relative "repository/setup"
require_relative "repository/verify"
require_relative "repository/rename"

module Workspace
  module Commands
    class Repository
      SUBCOMMANDS = {
        "setup" => Workspace::Commands::Repository::Setup,
        "verify" => Workspace::Commands::Repository::Verify,
        "rename" => Workspace::Commands::Repository::Rename
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

        context = Workspace::Context.new(root: Workspace::ROOT)
        subcommand.new(argv, stdin: stdin, stdout: stdout, stderr: stderr, context: context).call
      end

      private

      attr_reader :argv, :stdin, :stdout, :stderr

      def usage
        stderr.puts("Usage: bin/workspace repository <setup|verify|rename> [options]")
        1
      end
    end
  end
end
