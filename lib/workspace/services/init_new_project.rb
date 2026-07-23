#!/usr/bin/env ruby
# frozen_string_literal: true
# Guides first-time project setup by orchestrating checks, rename, validation, and optional dev services launch.

require "securerandom"
require "yaml"
require_relative "../../workspace"
require_relative "../context"
require_relative "bootstrap"
require_relative "cms/installer"
require_relative "doctor"
require_relative "github_repository_setup"
require_relative "init_new_project_options"
require_relative "init_step_runner"
require_relative "repository_remote_setup"
require_relative "rename_product_command"
require_relative "pull"
require_relative "validate_product"

module Workspace
  module Services
    class InitNewProject
      BACKEND_PURPOSE = "backend-api"
      FRONTEND_PURPOSE = "frontend-web-client"

      REFERENCE_DOCS = [
        "docs/local-development.md",
        "docs/scripting.md",
        "docs/openapi-workflow.md"
      ].freeze
      TEMPLATE_INSTALLATION_ID = "000000"
      INSTALLATION_ID_HEX_BYTES = 3
      INSTALLATION_ID_PATTERN = /\A[a-f0-9]{6}\z/

      def initialize(argv, stdin: $stdin, stdout: $stdout, context: Workspace::Context.new(root: Workspace::ROOT))
        @argv = argv.dup
        @stdin = stdin
        @stdout = stdout
        @context = context
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
        assign_installation_id_if_needed

        Workspace.section("Init: New Project Setup")
        Workspace.ok("Initializing new project: #{product_slug}")
        Workspace.info("This workflow will check environment, clone/bootstrap repos, rename templates, validate, and optionally launch dev services.")

        unless options.skip_setup_tools?
          return 1 unless step_runner.shell("Guided tool installation and auth setup", "install_local_dev_tools")
        end
        return 1 unless step_runner.shell("Environment prechecks", "preinstall_checks")
        return 1 unless step_runner.ruby("Environment diagnostics") { Workspace::Services::Doctor.new(context: context).call }
        return 1 unless step_runner.ruby("Repository bootstrap and dependency install") { Workspace::Services::Bootstrap.new(context: context).call }
        return 1 unless step_runner.ruby("Sync latest template changes") { Workspace::Services::Pull.new(context: context).call }

        remote_setup = github_repository_setup.call(options: options, product_slug: product_slug)
        return 1 unless remote_setup.success?

        return 1 unless step_runner.ruby("Rename templates for new project") { Workspace::Services::RenameProductCommand.new([product_slug], context: context).call }
        return 1 unless install_optional_cms_if_enabled(options)
        return 1 unless install_cms_frontend_dependencies_if_enabled(options)
        return 1 unless step_runner.ruby("Post-rename validation (tests/build checks)") { Workspace::Services::ValidateProduct.new([product_slug], context: context, stdin: stdin, stdout: stdout).call }
        return 1 unless repository_remote_setup.call(remote_setup)

        print_summary(product_slug)

        return 0 if options.no_dev?

        Workspace.info("Launching local development services to confirm setup is working (Ctrl+C to stop).")
        exec(Workspace.script_path("dev", context: context))
      end

      private

      attr_reader :argv, :stdin, :stdout, :context

      def print_summary(product_slug)
        api_repo = repository_path_for(BACKEND_PURPOSE) || "repos/#{product_slug}-api"
        web_repo = repository_path_for(FRONTEND_PURPOSE) || "repos/#{product_slug}-web"

        puts
        Workspace.ok("Project initialization completed successfully.")
        Workspace.info("Renamed repositories:")
        Workspace.info("- #{api_repo}")
        Workspace.info("- #{web_repo}")

        puts
        Workspace.info("Helpful references:")
        REFERENCE_DOCS.each { |path| Workspace.info("- #{path}") }
        Workspace.info("- #{api_repo}/docs/template-rename.md")
        Workspace.info("- #{web_repo}/docs/template-rename.md")
      end

      def github_repository_setup
        @github_repository_setup ||= Workspace::Services::GithubRepositorySetup.new(stdin: stdin, stdout: stdout, context: context)
      end

      def repository_remote_setup
        @repository_remote_setup ||= Workspace::Services::RepositoryRemoteSetup.new(context: context)
      end

      def step_runner
        @step_runner ||= Workspace::Services::InitStepRunner.new(context: context)
      end

      def repository_path_for(purpose)
        repo = repository_by_purpose(purpose)
        repo && repo["path"].to_s
      end

      def repository_by_purpose(purpose)
        Workspace.repositories(context: context).find { |repo| repo["purpose"].to_s == purpose }
      end

      def assign_installation_id_if_needed
        path = context.path("config", "project.yml")
        return unless File.exist?(path)

        manifest = YAML.safe_load_file(path, permitted_classes: [], aliases: false) || {}
        project = manifest["project"]
        return unless project.is_a?(Hash)

        existing = project["installation_id"].to_s.strip
        return if existing.match?(INSTALLATION_ID_PATTERN) && existing != TEMPLATE_INSTALLATION_ID

        installation_id = generate_installation_id
        project["installation_id"] = installation_id
        File.write(path, YAML.dump(manifest))
        Workspace.info("Assigned project installation_id: #{installation_id}")
      end

      def install_optional_cms_if_enabled(options)
        return true unless options.cms_enabled?

        step_runner.ruby("Install optional CMS feature (#{options.cms_provider})") do
          cms_installer.call(provider: options.cms_provider)
        end
      end

      def install_cms_frontend_dependencies_if_enabled(options)
        return true unless options.cms_enabled?

        frontend_relative_path = repository_path_for(FRONTEND_PURPOSE) || "repos/#{options.product_slug}-web"
        frontend_root = context.path(frontend_relative_path)

        step_runner.ruby("Install frontend dependencies for CMS feature") do
          installed = Workspace.run(
            "npm install",
            chdir: frontend_root,
            allow_failure: true,
            summary: "Failed to install frontend dependencies for CMS feature.",
            details: "Command: npm install | Directory: #{frontend_root}",
            fixes: [
              "Run npm install manually in #{frontend_relative_path}.",
              "Resolve dependency/auth/network issues, then re-run bin/init_new_project.",
              "After install succeeds, rerun validation with bin/workspace repository verify #{options.product_slug}."
            ]
          )

          installed ? 0 : 1
        end
      end

      def cms_installer
        @cms_installer ||= Workspace::Services::Cms::Installer.new(context: context, stdin: stdin, stdout: stdout)
      end

      def generate_installation_id
        SecureRandom.hex(INSTALLATION_ID_HEX_BYTES)
      end
    end
  end
end
