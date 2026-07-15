# frozen_string_literal: true

require_relative "../../workspace"
require_relative "credentials/init"
require_relative "credentials/configure"
require_relative "credentials/show"

module Workspace
  module Commands
    class Credentials
      SUBCOMMANDS = {
        "init" => Workspace::Commands::Credentials::Init,
        "configure" => Workspace::Commands::Credentials::Configure,
        "show" => Workspace::Commands::Credentials::Show
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
        stderr.puts("Usage: bin/workspace credentials <init|configure|show>")
        1
      end
    end
  end
end
