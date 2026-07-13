#!/usr/bin/env ruby
# frozen_string_literal: true
# Guides first-time project setup by orchestrating checks, rename, validation, and optional dev services launch.

require "shellwords"
require_relative "../../workspace"
require_relative "bootstrap"
require_relative "doctor"
require_relative "github_repository_setup"
require_relative "init_new_project_options"
require_relative "new_product"
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
          return 1 unless run_shell_step("Guided tool installation and auth setup", "install_local_dev_tools")
        end
        return 1 unless run_shell_step("Environment prechecks", "preinstall")
        return 1 unless run_command_step("Environment diagnostics") { Workspace::Services::Doctor.new.call }
        return 1 unless run_command_step("Repository bootstrap and dependency install") { Workspace::Services::Bootstrap.new.call }
        return 1 unless run_command_step("Sync latest template changes") { Workspace::Services::Pull.new.call }

        remote_setup = github_repository_setup.call(options: options, product_slug: product_slug)
        return 1 unless remote_setup.success?

        return 1 unless run_command_step("Rename templates for new project") { Workspace::Services::NewProduct.new([product_slug]).call }
        return 1 unless run_command_step("Post-rename validation (tests/build checks)") { Workspace::Services::ValidateProduct.new([product_slug]).call }
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

        Workspace.info("Configuring local git origins for product repositories")
        connect_local_repositories(targets)

        if remote_setup.push_after_setup?
          Workspace.info("Pushing initialized repositories to new remotes")
          return false unless push_repositories(targets)
        else
          Workspace.warn("Push step skipped (--no-push). Repositories are ready for manual push.")
        end

        true
      end

      def connect_local_repositories(targets)
        targets.each do |target|
          local_path = target[:local_path]
          absolute_path = File.join(Workspace::ROOT, local_path)
          next unless Dir.exist?(absolute_path)
          next unless Dir.exist?(File.join(absolute_path, ".git"))

          _origin_out, has_origin = Workspace.capture("git remote get-url origin", chdir: absolute_path)
          Workspace.run("git remote remove origin", chdir: absolute_path, allow_failure: true) if has_origin

          repo_url = "git@github.com:#{target[:github_ref]}.git"
          Workspace.run("git remote add origin #{Shellwords.escape(repo_url)}", chdir: absolute_path)
          Workspace.ok("Configured origin for #{target[:label]}: #{repo_url}")
        end
      end

      def push_repositories(targets)
        targets.each do |target|
          local_path = target[:local_path]
          absolute_path = File.join(Workspace::ROOT, local_path)
          next unless Dir.exist?(absolute_path)
          next unless Dir.exist?(File.join(absolute_path, ".git"))

          _, branch_ok = Workspace.capture("git symbolic-ref --quiet --short HEAD", chdir: absolute_path)
          unless branch_ok
            Workspace.warn("Skipping push for #{target[:label]}: repository has no active branch yet.")
            next
          end

          success = Workspace.run(
            "git push -u origin HEAD",
            chdir: absolute_path,
            allow_failure: true,
            summary: "Failed to push #{target[:label]} repository to remote.",
            details: "Remote may reject push due to permissions or branch protections.",
            fixes: [
              "Verify repository write access on #{target[:github_ref]}.",
              "Retry manually: git -C #{local_path} push -u origin HEAD",
              "If required, create default branch and re-run push."
            ]
          )
          return false unless success

          Workspace.ok("Pushed #{target[:label]} repository to #{target[:github_ref]}")
        end

        true
      end

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

      def unset_origin_remotes
        targets = remote_targets
        removed = []

        targets.each do |target|
          next unless Dir.exist?(target[:absolute_path])
          next unless Dir.exist?(File.join(target[:absolute_path], ".git"))

          _, has_origin = Workspace.capture("git remote get-url origin", chdir: target[:absolute_path])
          next unless has_origin

          success = Workspace.run("git remote remove origin", chdir: target[:absolute_path], allow_failure: true)
          removed << target if success
        end

        print_remote_reset_warning(removed, targets)
      end

      def remote_targets
        workspace_target = {
          label: "template workspace",
          relative_path: ".",
          absolute_path: Workspace::ROOT,
          suggested_github: "<your-org>/#{File.basename(Workspace::ROOT)}"
        }

        repo_targets = Workspace.repositories.map do |repo|
          relative_path = repo["path"].to_s
          {
            label: repo["name"].to_s,
            relative_path: relative_path,
            absolute_path: File.join(Workspace::ROOT, relative_path),
            suggested_github: repo["github"].to_s.empty? ? "<your-org>/<repo-name>" : repo["github"].to_s
          }
        end

        [workspace_target] + repo_targets
      end

      def print_remote_reset_warning(removed, targets)
        Workspace.warn("Git origin remotes for the template workspace and repos/ projects have been unset where present.")
        Workspace.warn("Set each remote to your own project location before pushing.")

        if removed.empty?
          Workspace.info("No existing origin remotes were found to remove.")
        else
          Workspace.info("Unset origin for:")
          removed.each do |target|
            Workspace.info("- #{target[:relative_path]} (#{target[:label]})")
          end
        end

        puts
        Workspace.info("Set your new origins with commands like:")
        targets.each do |target|
          escaped_path = Shellwords.escape(target[:relative_path])
          Workspace.info("git -C #{escaped_path} remote add origin git@github.com:#{target[:suggested_github]}.git")
        end
      end

      def github_repository_setup
        @github_repository_setup ||= Workspace::Services::GithubRepositorySetup.new(stdin: stdin, stdout: stdout)
      end

      def repository_path_for(purpose)
        repo = repository_by_purpose(purpose)
        repo && repo["path"].to_s
      end

      def repository_by_purpose(purpose)
        Workspace.repositories.find { |repo| repo["purpose"].to_s == purpose }
      end
    end
  end
end
