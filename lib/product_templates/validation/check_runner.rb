# frozen_string_literal: true

require_relative "result"

module ProductTemplates
  module Validation
    class CheckRunner
      def run(checks)
        checks.map { |check| run_check(check) }
      end

      private

      def run_check(check)
        unless Dir.exist?(check.directory)
          Workspace.warn("#{check.name} skipped: missing directory #{check.directory_label}")
          return Result.new(name: check.name, passed: false, note: "missing #{check.directory_label}")
        end

        passed = if check.callable
                   check.callable.call
                 else
                   Workspace.run(check.command, chdir: check.directory, allow_failure: true)
                 end
        Result.new(name: check.name, passed: passed, note: passed ? "passed" : "failed")
      end
    end
  end
end
