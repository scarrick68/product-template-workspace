#!/usr/bin/env ruby
# frozen_string_literal: true

require "shellwords"
require "tty-prompt"
require_relative "../../workspace"
require_relative "auth/github_auth"

module Workspace
  module Services
    class GithubRepositorySetup
      BACKEND_PURPOSE = "backend-api"
      FRONTEND_PURPOSE = "frontend-web-client"

      class Result
        attr_reader :create_remotes, :push_after_setup, :visibility, :targets

        def initialize(success:, create_remotes:, push_after_setup:, visibility:, targets:)
          @success = success
          @create_remotes = create_remotes
          @push_after_setup = push_after_setup
          @visibility = visibility
          @targets = targets
        end

        def success?
          @success
        end

        def create_remotes?
          @create_remotes
        end

        def push_after_setup?
          @push_after_setup
        end
      end

      def initialize(stdin: $stdin, stdout: $stdout)
        @stdin = stdin
        @stdout = stdout
        @prompt = TTY::Prompt.new(input: stdin, output: stdout)
      end

      def call(options:, product_slug:)
        targets = remote_repo_targets(product_slug)

        return manual_result(options, targets) unless should_create_remotes?(options)

        visibility = resolved_visibility(options)
        push_after_setup = resolved_push_after_setup(options)
        return fallback_manual_result(options, targets) unless verify_github_permissions
        return failure_result(options, targets) unless create_missing_remote_repositories(targets, visibility)

        Result.new(
          success: true,
          create_remotes: true,
          push_after_setup: push_after_setup,
          visibility: visibility,
          targets: targets
        )
      end

      private

      attr_reader :stdin, :stdout, :prompt

      def should_create_remotes?(options)
        return options.create_remotes? if options.create_remotes_explicit?

        prompt.yes?("Would you like this script to create backend/frontend remotes automatically?", default: false)
      end

      def resolved_visibility(options)
        return options.visibility if options.create_remotes_explicit? && !options.visibility.nil?

        prompt.yes?("Create remotes as private repositories?", default: true) ? "private" : "public"
      end

      def resolved_push_after_setup(options)
        return options.push_after_setup? if options.push_explicit?

        prompt.yes?("Push repositories after remote setup?", default: true)
      end

      def verify_github_permissions
        Workspace.info("Validating GitHub permissions for automated repository creation")
        Workspace.info("Required permissions: create repository, push code, and (for org owners) org repo creation rights.")
        Workspace.info("If using classic tokens, ensure repo scope is granted.")

        result = Workspace::Services::Auth::GithubAuth.new.call
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

      def confirm_remote_repositories_ready(targets)
        Workspace.warn("Before rename, confirm remote repositories exist (or are already prepared) on your git provider.")

        targets.each do |target|
          Workspace.info("Expected #{target[:label]} repository: #{target[:github_ref]}")
          next if prompt.yes?("Have you created this repo or confirmed it already exists?", default: false)

          Workspace.fail_with_help(
            "#{target[:label].capitalize} repository is not confirmed.",
            details: "Create or confirm remote repository '#{target[:github_ref]}', then rerun init.",
            fixes: [
              "Create '#{target[:github_ref]}' on your git provider, or confirm existing access.",
              "Re-run: bin/init_new_project <product-slug>",
              "Or run with --assume-repos-ready when this step is already handled."
            ]
          )
          return false
        end

        true
      end

      def create_missing_remote_repositories(targets, visibility)
        Workspace.info("Creating remote repositories on GitHub")

        targets.each do |target|
          next if repository_exists?(target[:github_ref])

          success = Workspace.run(
            "gh repo create #{Shellwords.escape(target[:github_ref])} --#{visibility} --confirm",
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
        _out, exists = Workspace.capture("gh repo view #{Shellwords.escape(github_ref)}")
        Workspace.info("Remote repository exists: #{github_ref}") if exists
        exists
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

      def repository_path_for(purpose)
        repo = repository_by_purpose(purpose)
        repo && repo["path"].to_s
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

      def manual_result(options, targets)
        unless options.assume_repos_ready? || confirm_remote_repositories_ready(targets)
          return failure_result(options, targets)
        end

        Result.new(
          success: true,
          create_remotes: false,
          push_after_setup: options.push_after_setup?,
          visibility: nil,
          targets: targets
        )
      end

      def fallback_manual_result(options, targets)
        Workspace.warn("Automatic remote creation is unavailable with current GitHub auth/permissions.")
        Workspace.warn("You must create remotes and make your initial commit / push yourself")

        unless options.assume_repos_ready? || confirm_remote_repositories_ready(targets)
          return failure_result(options, targets)
        end

        Result.new(
          success: true,
          create_remotes: false,
          push_after_setup: options.push_after_setup?,
          visibility: nil,
          targets: targets
        )
      end

      def failure_result(options, targets)
        Result.new(
          success: false,
          create_remotes: false,
          push_after_setup: options.push_after_setup?,
          visibility: nil,
          targets: targets
        )
      end
    end
  end
end