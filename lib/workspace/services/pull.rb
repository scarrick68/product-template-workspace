#!/usr/bin/env ruby
# frozen_string_literal: true
# Command object for fast-forward pulls across workspace repositories.

require_relative "../../workspace"

module Workspace
  module Services
    class Pull
      def initialize
        @failures = []
        @warnings = []
      end

      def call
        Workspace.section("Pull: Sync Repositories")
        Workspace.existing_repositories.each do |repo|
          pull_repository(repo)
        end

        finalize
      end

      private

      attr_reader :failures, :warnings

      def pull_repository(repo)
        name = Workspace.repo_name(repo)
        path = Workspace.repo_path(repo)

        return report_missing_git_metadata(name, path) unless git_repo?(path)

        puts "\n#{name}"
        process_repository_pull(name, path)
      end

      def process_repository_pull(name, path)
        start_branch = current_branch(name, path)
        return add_failure(name) unless start_branch

        begin
          update_main_branch(name, path, start_branch)
          rebase_starting_branch_when_clean(name, path, start_branch)
        ensure
          restore_original_branch(name, path, start_branch)
        end
      end

      def update_main_branch(name, path, start_branch)
        unless switch_to_ref(path, "main")
          add_failure(name)
          return
        end

        return unless main_clean?(name, path)

        ok = Workspace.run(
          "git pull --ff-only origin main",
          chdir: path,
          allow_failure: true,
          summary: "Pull failed for main branch in #{name}.",
          details: "Could not fast-forward pull origin/main while on main in #{path}.",
          assumptions: [
            "The repository has a local main branch tracking origin/main.",
            "Network and GitHub authentication are valid for pulling latest changes."
          ],
          fixes: [
            "Run gh auth status and verify authentication if this repository is private.",
            "Run git fetch origin main and inspect divergence/errors manually.",
            "Resolve branch protection/divergence issues, then retry bin/pull."
          ]
        )
        add_failure(name) unless ok

        return if start_branch == "main"

        switch_to_ref(path, start_branch)
      end

      def rebase_starting_branch_when_clean(name, path, start_branch)
        return if start_branch == "main"

        unless working_tree_clean?(path)
          warn_skip(
            name,
            "Skipping rebase for branch #{start_branch} because the working tree has uncommitted changes."
          )
          return
        end

        ok = Workspace.run(
          "git rebase main",
          chdir: path,
          allow_failure: true,
          summary: "Rebase failed for #{name}.",
          details: "Could not rebase #{start_branch} onto main in #{path}.",
          assumptions: [
            "The working branch is clean before rebase starts.",
            "Rebase can apply commits cleanly from #{start_branch} onto current main."
          ],
          fixes: [
            "Run git status in #{path} to inspect rebase state.",
            "Resolve conflicts, then run git rebase --continue or git rebase --abort.",
            "Retry bin/pull after branch history is in a healthy state."
          ]
        )
        add_failure(name) unless ok
      end

      def restore_original_branch(name, path, start_branch)
        return if start_branch.nil?

        restore_command = "git checkout #{start_branch}"
        ok = Workspace.run(
          restore_command,
          chdir: path,
          allow_failure: true,
          summary: "Could not restore original branch for #{name}.",
          details: "Failed to switch back to #{start_branch} in #{path}.",
          assumptions: [
            "The original branch still exists locally.",
            "No unresolved rebase/merge state is blocking branch checkout."
          ],
          fixes: [
            "Run git status in #{path} to inspect any in-progress operation.",
            "Resolve or abort rebase/merge state, then checkout #{start_branch} manually.",
            "Re-run bin/pull once repository state is clean."
          ]
        )
        add_failure(name) unless ok
      end

      def current_branch(name, path)
        branch_output, branch_ok = Workspace.capture("git branch --show-current", chdir: path)
        unless branch_ok
          Workspace.fail_with_help(
            "Could not determine current branch for #{name}.",
            details: "git branch --show-current failed in #{path}.",
            assumptions: [
              "Repository metadata is healthy and branch information can be read.",
              "Git command execution is available for branch discovery."
            ],
            fixes: [
              "Run git status in #{path} to inspect repository state.",
              "Fix repository issues and retry bin/pull."
            ]
          )
          return nil
        end

        branch = branch_output.strip
        return branch unless branch.empty?

        Workspace.fail_with_help(
          "Repository is not on a named branch for #{name}.",
          details: "Detached HEAD detected in #{path}. This workflow currently requires a named branch.",
          assumptions: [
            "Pull workflow records and restores repositories by branch name.",
            "Detached HEAD state does not provide a stable branch target for this command."
          ],
          fixes: [
            "Checkout a named branch in #{path} (for example: git checkout main).",
            "Re-run bin/pull after all repositories are on named branches."
          ]
        )
        nil
      end

      def switch_to_ref(path, ref)
        Workspace.run(
          "git checkout #{ref}",
          chdir: path,
          allow_failure: true,
          summary: "Could not switch repository to #{ref}.",
          details: "Checkout to #{ref} failed in #{path}.",
          assumptions: [
            "Branch #{ref} exists locally and is not blocked by unresolved git state.",
            "Uncommitted changes do not conflict with checkout targets."
          ],
          fixes: [
            "Run git branch to confirm #{ref} exists locally.",
            "Run git status and resolve in-progress operations before checkout.",
            "If branch is missing, create it from origin then retry."
          ]
        )
      end

      def main_clean?(name, path)
        return true if working_tree_clean?(path)

        warn_skip(
          name,
          "Skipping pull on main because main has uncommitted changes. No changes were made to uncommitted work."
        )
        false
      end

      def working_tree_clean?(path)
        output, ok = Workspace.capture("git status --porcelain", chdir: path)
        ok && output.strip.empty?
      end

      def warn_skip(name, message)
        warnings << "#{name}: #{message}"
        Workspace.warn("#{name}: #{message}")
      end

      def add_failure(name)
        failures << name unless failures.include?(name)
      end

      def git_repo?(path)
        Dir.exist?(File.join(path, ".git"))
      end

      def report_missing_git_metadata(name, path)
        Workspace.fail_with_help(
          "Repository metadata missing for #{name}.",
          details: "Expected a git repository at #{path}, but .git was not found.",
          assumptions: [
            "Pull assumes each configured repository path points to a valid git working tree.",
            "A missing .git directory usually means the repository was not cloned correctly."
          ],
          fixes: [
            "Confirm config/repos.yml points to the correct path.",
            "Run bin/bootstrap to clone missing repositories.",
            "If this repository should not be pulled, remove or mark it optional in config/repos.yml."
          ]
        )
      end

      def finalize
        if warnings.any?
          Workspace.warn("pull warnings:")
          warnings.each { |warning| Workspace.warn("- #{warning}") }
        end

        return success if failures.empty?

        Workspace.fail_with_help(
          "Pull failed for one or more repositories.",
          details: "Failed repositories: #{failures.join(', ')}",
          assumptions: [
            "Each repository should be on a pullable branch with no blocking auth or divergence issues.",
            "Network and GitHub credentials must be valid for all configured repositories."
          ],
          fixes: [
            "Review command output above for each failed git pull.",
            "Resolve branch divergence, local conflicts, or authentication issues.",
            "If needed, run pull manually in each listed repository, then retry bin/pull."
          ]
        )
        1
      end

      def success
        Workspace.ok("pull complete")
        0
      end
    end
  end
end
