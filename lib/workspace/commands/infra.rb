# frozen_string_literal: true

require_relative "../../workspace"
require_relative "infra/doctor"
require_relative "infra/configure"
require_relative "infra/plan"
require_relative "infra/apply"
require_relative "infra/safe_destroy"
require_relative "infra/total_destruction"
require_relative "infra/digitalocean"

module Workspace
  module Commands
    class Infra
      SUBCOMMANDS = {
        "doctor" => Workspace::Commands::Infra::Doctor,
        "configure" => Workspace::Commands::Infra::Configure,
        "plan" => Workspace::Commands::Infra::Plan,
        "apply" => Workspace::Commands::Infra::Apply,
        "safe_destroy" => Workspace::Commands::Infra::SafeDestroy,
        "total_destruction" => Workspace::Commands::Infra::TotalDestruction,
        "digitalocean" => Workspace::Commands::Infra::Digitalocean
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
        stderr.puts("Usage: bin/workspace infra <doctor|configure|plan|apply|safe_destroy|total_destruction|digitalocean> [options]")
        1
      end
    end
  end
end
