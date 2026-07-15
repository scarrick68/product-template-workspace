#!/usr/bin/env ruby
# frozen_string_literal: true

require "shellwords"
require_relative "../../workspace"

module Workspace
  module Services
    # Runs init workflow steps with consistent section output and failure handling.
    # Simply wraps shell commands and ruby blocks with a consistent interface for logging, error handling, and user guidance.
    class InitStepRunner
      def initialize(context:)
        @context = context
      end

      def shell(label, script_name, args: [])
        Workspace.section("Init Step: #{label}", color: :magenta, divider_char: "-")

        command_parts = [Workspace.script_path(script_name, context: context)] + args
        command = command_parts.map { |part| Shellwords.escape(part) }.join(" ")

        Workspace.run(
          command,
          chdir: context.root,
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

      def ruby(label)
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

      private

      attr_reader :context
    end
  end
end
