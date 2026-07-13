#!/usr/bin/env ruby
# frozen_string_literal: true
# Guides first-time project setup by orchestrating checks, rename, validation, and optional dev services launch.

require "shellwords"
require_relative "../../workspace"
require_relative "bootstrap_command"
require_relative "doctor_command"
require_relative "github_repository_setup"
require_relative "init_new_project_options"
require_relative "new_product_command"
require_relative "pull_command"
require_relative "validate_product_command"

module Workspace
  module Commands
    class InitNewProjectCommand
      BACKEND_PURPOSE = "backend-api"
      FRONTEND_PURPOSE = "frontend-web-client"

      REFERENCE_DOCS = [
        "docs/local-development.md",
        "docs/scripting.md",
        "docs/openapi-workflow.md"
      ].freeze

      def initialize(argv, stdin: $stdin, stdout: $stdout)
        @argv = argv.dup
        @stdin = stdin
        @stdout = stdout
      end

      def call
        options = InitNewProjectOptions.parse(argv, stdout: stdout)
        return 0 if options.help_requested?

        unless options.valid?
          Workspace.fail_with_help(
            options.failure_summary,
            details: options.failure_details,
            fixes: options.failure_fixes
          )
          return 1
        end

        product_slug = options.product_slug

        Workspace.section("Init: New Project Setup")
        Workspace.ok("Initializing new project: #{product_slug}")
        Workspace.info("This workflow will check environment, clone/bootstrap repos, rename templates, validate, and optionally launch dev services.")

        unless options.skip_setup_tools?
          return 1 unless run_shell_step("Guided dev env tool installation and auth setup", "install_local_dev_tools")
        end
        return 1 unless run_shell_step("Environment prechecks", "preinstall")
        return 1 unless run_command_step("Environment diagnostics") { Workspace::Commands::DoctorCommand.new.call }
        return 1 unless run_command_step("Repository bootstrap and dependency install") { Workspace::Commands::BootstrapCommand.new.call }
        return 1 unless run_command_step("Sync latest template changes") { Workspace::Commands::PullCommand.new.call }

        remote_setup = github_repository_setup.call(options: options, product_slug: product_slug)
        return 1 unless remote_setup.success?

        return 1 unless run_command_step("Rename templates for new project") { Workspace::Commands::NewProductCommand.new([product_slug]).call }
        return 1 unless run_command_step("Post-rename validation (tests/build checks)") { Workspace::Commands::ValidateProductCommand.new([product_slug]).call }
        return 1 unless configure_remotes_and_push(remote_setup)

        print_summary(product_slug)

        return 0 if options.no_dev?

        Workspace.info("Launching local development services to confirm setup is working (Ctrl+C to stop).")
        exec(Workspace.script_path("dev"))
      end

      private

      attr_reader :argv, :stdin, :stdout

      def run_shell_step(label, script_name, args = [])
        Workspace.section("Init Step: #{label}", color: :magenta, divider_char: "-")

        command_parts = [Workspace.script_path(script_name)] + args
        command = command_parts.map { |part| Shellwords.escape(part) }.join(" ")

        Workspace.run(
          command,
          chdir: Workspace::ROOT,
          allow_failure: true,
          summary: "Init workflow failed at step: #{label}.",
          details: "Command: #{command}",
          fixes: [
            "Fix the reported issue above.",
            "Retry the failed command directly to validate fix.",
            "Re-run bin/init_new_project once the step succeeds."
          ]
        )
      end

      def run_command_step(label)
        Workspace.section("Init Step: #{label}", color: :magenta, divider_char: "-")

        exit_code = begin
          yield
        rescue SystemExit => e
          e.status
        end

        return true if exit_code.to_i.zero?

        Workspace.fail_with_help(
          "Init workflow failed at step: #{label}.",
          details: "Command object returned exit code #{exit_code}.",
          fixes: [
            "Fix the reported issue above.",
            "Run the corresponding command directly to validate the fix.",
            "Re-run bin/init_new_project once the step succeeds."
          ]
        )
        false
      end

      def configure_remotes_and_push(remote_setup)
        if remote_setup.create_remotes?
          targets = remote_setup.targets
        else
          unset_origin_remotes
          return true
        end

        #!/usr/bin/env ruby
        # frozen_string_literal: true

        require_relative "../services/init_new_project"

        module Workspace
          module Commands
            # Compatibility shim: prefer Workspace::Services::InitNewProject.
            class InitNewProjectCommand < Workspace::Services::InitNewProject
            end
          end
        end

