# frozen_string_literal: true

module Workspace
  module Services
    module Infra
      # Parses positional command-line arguments for `bin/infra` and returns
      # the selected command action/environment pair used by ProvisionInfra.
      class CommandLineOptions
        SUPPORTED_COMMANDS = %w[doctor configure plan apply safe_destroy total_destruction].freeze
        DEFAULT_ENVIRONMENT = "production"

        Result = Struct.new(:action, :environment, :exit_code, keyword_init: true) do
          def valid?
            exit_code.nil?
          end
        end

        def self.parse(argv)
          first_arg = argv.first.to_s.strip

          if first_arg.empty?
            Workspace.info("Usage: bin/infra [doctor|configure|plan|apply|safe_destroy|total_destruction] [environment]")
            Workspace.info("Examples: bin/infra doctor | bin/infra configure production | bin/infra plan production | bin/infra safe_destroy production")
            return Result.new(exit_code: 1)
          end

          unless SUPPORTED_COMMANDS.include?(first_arg)
            Workspace.fail_with_help(
              "Unsupported infra action '#{first_arg}'.",
              details: "Supported actions: #{SUPPORTED_COMMANDS.join(', ')}",
              fixes: [
                "Run: bin/infra doctor",
                "Run: bin/infra configure production",
                "Run: bin/infra plan production",
                "Run: bin/infra apply production",
                "Run: bin/infra safe_destroy production",
                "Run: bin/infra total_destruction production"
              ]
            )

            return Result.new(exit_code: 1)
          end

          environment = argv[1].to_s.strip
          environment = DEFAULT_ENVIRONMENT if environment.empty?

          Result.new(action: first_arg, environment: environment)
        end
      end
    end
  end
end