# frozen_string_literal: true

require "open3"
require "set"

module Workspace
  module Services
    module Git
      # Commits all changes produced by one isolated installer or bootstrap task.
      #
      # Callers should enforce a clean tree before a task starts, then commit all
      # resulting changes after the task succeeds.
      class ChangesCommitter
        Marker = Data.define(:changed_paths)

        class OperationError < StandardError
          attr_reader :details

          def initialize(details)
            super(details)
            @details = details
          end
        end

        def initialize(context:)
          @context = context
        end

        def available?
          _output, status = Open3.capture2e("git", "rev-parse", "--is-inside-work-tree", chdir: context.root)
          status.success?
        rescue Errno::ENOENT
          false
        end

        def clean?
          return true unless available?

          output, status = Open3.capture2e("git", "status", "--porcelain", chdir: context.root)
          raise OperationError, "git status failed: #{output.strip}" unless status.success?

          output.strip.empty?
        end

        def ensure_clean!
          return unless available?
          return if clean?

          raise OperationError,
                "Git working tree must be clean before running this installer task."
        end

        def commit_changes(message:)
          return false unless available?
          return false if clean?

          run_git!("add", "--all")
          run_git!("commit", "-m", message)

          true
        end

        def mark
          Marker.new(changed_paths: changed_paths.to_set)
        end

        def commit_since(marker, message:)
          return false unless available?

          paths = changed_paths.reject { |path| marker.changed_paths.include?(path) }
          return false if paths.empty?

          run_git!("add", "--", *paths)
          return false unless staged_changes_for?(paths)

          run_git!("commit", "-m", message, "--", *paths)
          true
        end

        def changed_paths
          return [] unless available?

          tracked = run_git!("diff", "--name-only", "-z", "HEAD")
          untracked = run_git!("ls-files", "--others", "--exclude-standard", "-z")
          parse_paths(tracked, untracked)
        end

        private

        attr_reader :context

        def staged_changes_for?(paths)
          _output, status = Open3.capture2e("git", "diff", "--cached", "--quiet", "--", *paths, chdir: context.root)
          !status.success?
        rescue Errno::ENOENT
          raise OperationError, "Git executable was not found."
        end

        def parse_paths(*outputs)
          outputs.flat_map { |output| output.split("\0") }.reject(&:empty?).uniq
        end

        def run_git!(*args)
          output, status = Open3.capture2e("git", *args, chdir: context.root)
          return output if status.success?

          raise OperationError, "git #{args.join(' ')} failed: #{output.strip}"
        end
      end
    end
  end
end
