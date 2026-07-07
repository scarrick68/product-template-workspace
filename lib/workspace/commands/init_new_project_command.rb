#!/usr/bin/env ruby
# frozen_string_literal: true
# Guides first-time project setup by orchestrating checks, rename, validation, and optional dev services launch.

require "shellwords"
require_relative "../../workspace"
require_relative "auth/github_auth_command"

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
        options = parse_options
        return 1 unless options

        product_slug = options[:product_slug]
        return usage unless valid_slug?(product_slug)

        Workspace.section("Init: New Project Setup")
        Workspace.ok("Initializing new project: #{product_slug}")
        Workspace.info("This workflow will check environment, clone/bootstrap repos, rename templates, validate, and optionally launch dev services.")

        unless options[:skip_setup_tools]
          return 1 unless run_step("Guided tool installation and auth setup", "setup_tools")
        end
        return 1 unless run_step("Environment prechecks", "preinstall")
        return 1 unless run_step("Environment diagnostics", "doctor")
        return 1 unless run_step("Repository bootstrap and dependency install", "bootstrap")
        return 1 unless run_step("Sync latest template changes", "pull")
        return 1 unless resolve_gh_remote_options!(options)
        return 1 unless verify_github_permissions(options)
        return 1 unless confirm_remote_repositories_ready(product_slug, options)
        return 1 unless run_step("Rename templates for new project", "new_product", [product_slug])
        return 1 unless run_step("Post-rename validation (tests/build checks)", "validate_product", [product_slug])
        return 1 unless configure_remotes_and_push(product_slug, options)

        print_summary(product_slug)

        return 0 if options[:no_dev]

        Workspace.info("Launching local development services to confirm setup is working (Ctrl+C to stop).")
        exec(Workspace.script_path("dev"))
      end

      private

      attr_reader :argv, :stdin, :stdout

      def parse_options
        options = {
          no_dev: false,
          skip_setup_tools: false,
          assume_repos_ready: false,
          create_remotes: false,
          visibility: nil,
          push_after_setup: true
        }

        argv.each do |arg|
          case arg
          when "--no-dev"
            options[:no_dev] = true
          when "--skip-setup-tools"
            options[:skip_setup_tools] = true
          when "--assume-repos-ready"
            options[:assume_repos_ready] = true
          when "--create-remotes"
            options[:create_remotes] = true
          when "--public"
            options[:create_remotes] = true
            options[:visibility] = "public"
          when "--private"
            options[:create_remotes] = true
            options[:visibility] = "private"
          when "--no-push"
            options[:push_after_setup] = false
          when "--push"
            options[:push_after_setup] = true
          when "-h", "--help"
            return nil
          else
            options[:product_slug] ||= arg
          end
        end

        options
      end

      def valid_slug?(value)
        value.to_s.match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/)
      end

      def usage
        Workspace.fail_with_help(
          "Missing or invalid product slug.",
          details: "Usage: bin/init_new_project <product-slug> [--no-dev] [--skip-setup-tools] [--assume-repos-ready] [--create-remotes] [--public|--private] [--push|--no-push]",
          fixes: [
            "Use kebab-case product slug (example: my-super-app).",
            "Run: bin/init_new_project my-super-app",
            "Use --no-dev if you want setup without launching long-running services.",
            "Use --skip-setup-tools if your machine is already configured and you want to skip guided installs/auth prompts.",
            "Use --assume-repos-ready if remote backend/frontend repos are already created.",
            "Use --create-remotes to create backend/frontend GitHub repositories automatically."
          ]
        )
        1
      end

      def resolve_gh_remote_options!(options)
        return true unless options[:create_remotes]

        return true if %w[public private].include?(options[:visibility])

        stdout.print("Create remotes as public repositories? [y/N]: ")
        answer = stdin.gets&.strip.to_s
        options[:visibility] = answer.match?(/\A(y|yes)\z/i) ? "public" : "private"
        Workspace.info("Selected remote visibility: #{options[:visibility]}")
        true
      end

      def verify_github_permissions(options)
        return true unless options[:create_remotes]

        Workspace.info("Validating GitHub permissions for automated repository creation")
        Workspace.info("Required permissions: create repository, push code, and (for org owners) org repo creation rights.")
        Workspace.info("If using classic tokens, ensure repo scope is granted.")

        result = Workspace::Commands::Auth::GithubAuthCommand.new.call
        return true if result.zero?

        Workspace.fail_with_help(
          "GitHub auth checks failed for --create-remotes workflow.",
          details: "Run bin/github_auth_doctor and resolve reported issues before retrying init.",
          fixes: [
            "Run: bin/github_auth_doctor",
            "Refresh gh auth: gh auth refresh -s repo",
            "Confirm org-level repo creation permissions if using an organization owner"
          ]
        )
        false
      end

      def confirm_remote_repositories_ready(product_slug, options)
        return true if options[:create_remotes]
        return true if options[:assume_repos_ready]

        backend_ref = expected_remote_ref(BACKEND_PURPOSE, "#{product_slug}-api")
        frontend_ref = expected_remote_ref(FRONTEND_PURPOSE, "#{product_slug}-web")

        Workspace.warn("Before rename, confirm remote repositories exist (or are already prepared) on your git provider.")
        return false unless confirm_repository_readiness("backend", backend_ref)
        return false unless confirm_repository_readiness("frontend", frontend_ref)

        true
      end

      def expected_remote_ref(purpose, default_name)
        repo = repository_by_purpose(purpose)
        github = repo && repo["github"].to_s
        owner = github.split("/", 2).first
        return default_name if owner.nil? || owner.empty?

        "#{owner}/#{default_name}"
      end

      def repository_by_purpose(purpose)
        Workspace.repositories.find { |repo| repo["purpose"].to_s == purpose }
      end

      def confirm_repository_readiness(kind, ref)
        Workspace.info("Expected #{kind} repository: #{ref}")
        stdout.print("Have you created this repo or confirmed it already exists? [y/N]: ")
        answer = stdin.gets

        return true if answer && answer.strip.match?(/\A(y|yes)\z/i)

        Workspace.fail_with_help(
          "#{kind.capitalize} repository is not confirmed.",
          details: "Create or confirm remote repository '#{ref}', then rerun init.",
          fixes: [
            "Create '#{ref}' on your git provider, or confirm existing access.",
            "Re-run: bin/init_new_project <product-slug>",
            "Or run with --assume-repos-ready when this step is already handled."
          ]
        )
        false
      end

      def run_step(label, script_name, args = [])
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

      def configure_remotes_and_push(product_slug, options)
        targets = remote_repo_targets(product_slug)

        if options[:create_remotes]
          Workspace.info("Creating remote repositories on GitHub")
          return false unless create_remote_repositories(targets, options)
        else
          unset_origin_remotes
        end

        return true unless options[:create_remotes]

        Workspace.info("Configuring local git origins for product repositories")
        connect_local_repositories(targets)

        if options[:push_after_setup]
          Workspace.info("Pushing initialized repositories to new remotes")
          return false unless push_repositories(targets)
        else
          Workspace.warn("Push step skipped (--no-push). Repositories are ready for manual push.")
        end

        true
      end

      def remote_repo_targets(product_slug)
        [
          {
            label: "backend",
            local_path: repository_path_for(BACKEND_PURPOSE),
            github_ref: expected_remote_ref(BACKEND_PURPOSE, "#{product_slug}-api")
          },
          {
            label: "frontend",
            local_path: repository_path_for(FRONTEND_PURPOSE),
            github_ref: expected_remote_ref(FRONTEND_PURPOSE, "#{product_slug}-web")
          }
        ]
      end

      def create_remote_repositories(targets, options)
        targets.each do |target|
          next if repository_exists?(target[:github_ref])

          success = Workspace.run(
            "gh repo create #{Shellwords.escape(target[:github_ref])} --#{options[:visibility]} --confirm",
            chdir: Workspace::ROOT,
            allow_failure: true,
            summary: "Failed to create #{target[:label]} repository #{target[:github_ref]}.",
            details: "Your account may not have permission to create repositories for this owner.",
            fixes: [
              "Verify owner access in GitHub for #{target[:github_ref].split('/', 2).first}.",
              "Run: gh auth status -t and confirm repo creation permissions.",
              "Create repository manually, then re-run with --assume-repos-ready."
            ]
          )
          return false unless success

          Workspace.ok("Created remote repository #{target[:github_ref]}")
        end

        true
      end

      def repository_exists?(github_ref)
        _out, ok = Workspace.capture("gh repo view #{Shellwords.escape(github_ref)}")
        Workspace.info("Remote repository exists: #{github_ref}") if ok
        ok
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

      def repository_path_for(purpose)
        repo = repository_by_purpose(purpose)
        repo && repo["path"].to_s
      end
    end
  end
end
