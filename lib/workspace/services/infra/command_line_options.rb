# frozen_string_literal: true

require "optparse"

module Workspace
  module Services
    module Infra
      # Parses positional command-line arguments for `bin/infra` and returns
      # the selected command action/environment pair used by ProvisionInfra.
      class CommandLineOptions
        SUPPORTED_COMMANDS = %w[doctor configure plan apply safe_destroy total_destruction].freeze
        DEFAULT_ENVIRONMENT = "production"

        Result = Struct.new(:action, :environment, :first_deploy_setup, :exit_code, keyword_init: true) do
          def valid?
            exit_code.nil?
          end
        end

        def self.parse(argv)
          args = argv.dup
          first_arg = args.shift.to_s.strip

          if first_arg.empty?
            print_usage
            return Result.new(exit_code: 1)
          end

          unless SUPPORTED_COMMANDS.include?(first_arg)
            Workspace.fail_with_help(
              "Unsupported infra action '#{first_arg}'.",
              details: "Supported actions: #{SUPPORTED_COMMANDS.join(', ')}",
              fixes: [
                "Run: bin/workspace infra doctor",
                "Run: bin/workspace infra configure production",
                "Run: bin/workspace infra plan production",
                "Run: bin/workspace infra apply production",
                "Run: bin/workspace infra safe_destroy production",
                "Run: bin/workspace infra total_destruction production"
              ]
            )

            return Result.new(exit_code: 1)
          end

          first_deploy_setup = false
          option_parser = OptionParser.new do |opts|
            opts.on("--first-deploy-setup", "Run one-time post-apply bootstraps (Blazer defaults and admin bootstrap)") do
              first_deploy_setup = true
            end
          end

          begin
            option_parser.parse!(args)
          rescue OptionParser::ParseError => e
            Workspace.fail_with_help(
              "Invalid infra option.",
              details: e.message,
              fixes: [
                "Run: bin/workspace infra #{first_arg} #{DEFAULT_ENVIRONMENT}",
                "For initial production bootstrap, run: bin/workspace infra apply #{DEFAULT_ENVIRONMENT} --first-deploy-setup"
              ]
            )
            return Result.new(exit_code: 1)
          end

          if first_deploy_setup && first_arg != "apply"
            Workspace.fail_with_help(
              "--first-deploy-setup is only valid with infra apply.",
              details: "Received action '#{first_arg}'.",
              fixes: [
                "Use: bin/workspace infra apply #{DEFAULT_ENVIRONMENT} --first-deploy-setup",
                "Or remove --first-deploy-setup for non-apply actions."
              ]
            )
            return Result.new(exit_code: 1)
          end

          if args.length > 1
            Workspace.fail_with_help(
              "Too many positional arguments for infra #{first_arg}.",
              details: "Expected optional [environment], got: #{args.join(' ')}",
              fixes: [
                "Use: bin/workspace infra #{first_arg} #{DEFAULT_ENVIRONMENT}",
                "For initial production bootstrap, run: bin/workspace infra apply #{DEFAULT_ENVIRONMENT} --first-deploy-setup"
              ]
            )
            return Result.new(exit_code: 1)
          end

          environment = args.first.to_s.strip
          environment = DEFAULT_ENVIRONMENT if environment.empty?

          Result.new(action: first_arg, environment: environment, first_deploy_setup: first_deploy_setup)
        end

        def self.print_usage
          Workspace.info("Usage: bin/workspace infra [doctor|configure|plan|apply|safe_destroy|total_destruction] [environment] [--first-deploy-setup]")
          Workspace.info("Examples: bin/workspace infra doctor | bin/workspace infra configure production | bin/workspace infra plan production")
          Workspace.info("          bin/workspace infra apply production | bin/workspace infra apply production --first-deploy-setup")
        end
      end
    end
  end
end