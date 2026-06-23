#!/usr/bin/env ruby
# frozen_string_literal: true
# Command object for cross-repository git status summaries.

require_relative "../../workspace"

module Workspace
  module Commands
    class StatusCommand
      def call
        Workspace.existing_repositories.each do |repo|
          report_repository_status(repo)
        end

        0
      end

      private

      def report_repository_status(repo)
        name = Workspace.repo_name(repo)
        path = Workspace.repo_path(repo)

        return report_missing_git_metadata(name, path) unless git_repo?(path)

        output, ok = Workspace.capture("git status --short --branch", chdir: path)
        return report_status_command_failure(name, path) unless ok

        puts format_status_line(name, output)
      end

      def git_repo?(path)
        Dir.exist?(File.join(path, ".git"))
      end

      def report_missing_git_metadata(name, path)
        Workspace.fail_with_help(
          "Repository metadata missing for #{name}.",
          details: "Expected a git repository at #{path}, but .git was not found.",
          fixes: [
            "Confirm config/repos.yml points to the correct repository path.",
            "If the folder is missing, run bin/bootstrap or clone the repository manually.",
            "If the folder is not meant to be tracked, remove or mark it optional in config/repos.yml."
          ],
          assumptions: [
            "Status assumes each configured path contains a cloned git repository.",
            "If .git is missing, workspace metadata likely points to the wrong directory."
          ]
        )
      end

      def report_status_command_failure(name, path)
        Workspace.fail_with_help(
          "Could not read git status for #{name}.",
          details: "The command 'git status --short --branch' failed in #{path}.",
          fixes: [
            "Run the same git status command manually in #{path} to inspect the exact git error.",
            "Resolve repository issues such as permissions, lockfiles, or git corruption.",
            "Re-run bin/status after git status succeeds."
          ],
          assumptions: [
            "Git is installed and the repository is in a healthy state.",
            "Filesystem permissions allow reading the repository metadata and working tree."
          ]
        )
      end

      def format_status_line(name, output)
        lines = output.lines.map(&:rstrip)
        branch_line = lines.find { |line| line.start_with?("##") } || "## unknown"
        branch = branch_line.sub("## ", "")
        modified_count = lines.reject { |line| line.start_with?("##") || line.empty? }.size
        state = modified_count.zero? ? "clean" : "#{modified_count} modified"

        format("%-20s %-20s %s", name, branch, state)
      end
    end
  end
end
