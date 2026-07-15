#!/usr/bin/env ruby
# frozen_string_literal: true

require "shellwords"
require_relative "../../workspace"

module Workspace
  module Services
    # Applies the repository remote decisions produced by GithubRepositorySetup.
    #
    # When GitHub repositories were created, this service points each local
    # repository at its new GitHub repository and optionally pushes it.
    #
    # When remote creation was skipped, it removes inherited template origins
    # and prints commands for configuring replacement origins manually.
    class RepositoryRemoteSetup
      def initialize(context:)
        @context = context
      end

      def call(repository_setup_result)
        unless repository_setup_result.create_remotes?
          detach_template_origins_for_manual_setup
          return true
        end

        repositories = repository_setup_result.targets

        attach_local_repositories_to_github(repositories)

        if repository_setup_result.push_after_setup?
          push_initial_branches_to_github(repositories)
        else
          Workspace.warn(
            "Push step skipped (--no-push). Repositories are ready for manual push."
          )
          true
        end
      end

      private

      attr_reader :context

      def attach_local_repositories_to_github(repositories)
        Workspace.info(
          "Configuring product repositories to use their new GitHub origins"
        )

        repositories.each do |repository|
          repository_path = absolute_repository_path(repository)
          next unless git_repository?(repository_path)

          replace_origin_with_github_repository(repository, repository_path)
        end
      end

      def replace_origin_with_github_repository(repository, repository_path)
        remove_existing_origin(repository_path)

        github_url = github_ssh_url(repository[:github_ref])

        Workspace.run(
          "git remote add origin #{Shellwords.escape(github_url)}",
          chdir: repository_path
        )

        Workspace.ok(
          "Configured origin for #{repository[:label]}: #{github_url}"
        )
      end

      def remove_existing_origin(repository_path)
        _, origin_exists = Workspace.capture(
          "git remote get-url origin",
          chdir: repository_path
        )

        return unless origin_exists

        Workspace.run(
          "git remote remove origin",
          chdir: repository_path,
          allow_failure: true
        )
      end

      def push_initial_branches_to_github(repositories)
        Workspace.info(
          "Pushing initialized product repositories to GitHub"
        )

        repositories.each do |repository|
          repository_path = absolute_repository_path(repository)
          next unless git_repository?(repository_path)
          next unless active_branch?(repository, repository_path)

          return false unless push_current_branch(repository, repository_path)
        end

        true
      end

      # We only auto-push when the repo is on a named branch.
      # `git push -u origin HEAD` in a detached HEAD state is ambiguous for this
      # workflow and can create confusing refs, so we skip and ask for manual follow-up.
      def active_branch?(repository, repository_path)
        _, branch_exists = Workspace.capture(
          "git symbolic-ref --quiet --short HEAD",
          chdir: repository_path
        )

        unless branch_exists
          Workspace.warn(
            "Skipping push for #{repository[:label]}: " \
            "repository has no active branch yet."
          )
        end

        branch_exists
      end

      def push_current_branch(repository, repository_path)
        success = Workspace.run(
          "git push -u origin HEAD",
          chdir: repository_path,
          allow_failure: true,
          summary: "Failed to push #{repository[:label]} repository to GitHub.",
          details: "The remote may reject the push because of permissions or branch protections.",
          fixes: [
            "Verify repository write access on #{repository[:github_ref]}.",
            "Retry manually: git -C #{repository[:local_path]} push -u origin HEAD",
            "If required, create a default branch and retry the push."
          ]
        )

        return false unless success

        Workspace.ok(
          "Pushed #{repository[:label]} repository to #{repository[:github_ref]}"
        )

        true
      end

      def detach_template_origins_for_manual_setup
        repositories = repositories_requiring_manual_remote_setup
        detached_repositories = detach_existing_origins(repositories)

        print_manual_remote_setup_instructions(
          detached_repositories,
          repositories
        )
      end

      def detach_existing_origins(repositories)
        repositories.filter_map do |repository|
          repository_path = repository[:absolute_path]
          next unless git_repository?(repository_path)
          next unless origin_configured?(repository_path)

          detached = Workspace.run(
            "git remote remove origin",
            chdir: repository_path,
            allow_failure: true
          )

          repository if detached
        end
      end

      def repositories_requiring_manual_remote_setup
        [
          workspace_repository_for_manual_setup,
          *child_repositories_for_manual_setup
        ]
      end

      def workspace_repository_for_manual_setup
        {
          label: "template workspace",
          relative_path: ".",
          absolute_path: context.root,
          suggested_github_ref: "<your-org>/#{File.basename(context.root)}"
        }
      end

      def child_repositories_for_manual_setup
        Workspace.repositories(context: context).map do |repository|
          relative_path = repository["path"].to_s
          configured_github_ref = repository["github"].to_s

          {
            label: repository["name"].to_s,
            relative_path: relative_path,
            absolute_path: context.path(relative_path),
            suggested_github_ref: configured_github_ref.empty? ?
              "<your-org>/<repo-name>" :
              configured_github_ref
          }
        end
      end

      def print_manual_remote_setup_instructions(detached_repositories, repositories)
        Workspace.warn(
          "Inherited template origins have been removed where present."
        )
        Workspace.warn(
          "Configure each repository with its project-specific GitHub origin before pushing."
        )

        if detached_repositories.empty?
          Workspace.info("No existing origin remotes were found.")
        else
          Workspace.info("Removed origin from:")

          detached_repositories.each do |repository|
            Workspace.info(
              "- #{repository[:relative_path]} (#{repository[:label]})"
            )
          end
        end

        puts
        Workspace.info("Configure replacement origins with commands such as:")

        repositories.each do |repository|
          relative_path = Shellwords.escape(repository[:relative_path])
          github_url = github_ssh_url(repository[:suggested_github_ref])

          Workspace.info(
            "git -C #{relative_path} remote add origin #{github_url}"
          )
        end
      end

      def absolute_repository_path(repository)
        context.path(repository[:local_path])
      end

      def git_repository?(path)
        Dir.exist?(path) && Dir.exist?(File.join(path, ".git"))
      end

      def origin_configured?(repository_path)
        _, origin_exists = Workspace.capture(
          "git remote get-url origin",
          chdir: repository_path
        )

        origin_exists
      end

      def github_ssh_url(github_ref)
        "git@github.com:#{github_ref}.git"
      end
    end
  end
end
