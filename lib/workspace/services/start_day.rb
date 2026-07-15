#!/usr/bin/env ruby
# frozen_string_literal: true
# Command object for running the daily workflow orchestration.

require_relative "../../workspace"

module Workspace
  module Services
    class StartDay
      WORKFLOW_STEPS = [
        "preinstall_checks",
        "doctor",
        "pull",
        "status",
        "sync-openapi",
        "bootstrap"
      ].freeze

      def initialize(argv)
        @argv = argv
      end

      def call
        print_command_header
        return 1 unless run_workflow_steps

        maybe_start_dev_services
      end

      private

      attr_reader :argv

      def run_workflow_steps
        total = WORKFLOW_STEPS.length

        WORKFLOW_STEPS.each_with_index do |step, index|
          return false unless run_step(step, index + 1, total)
        end

        true
      end

      def run_step(step, position, total)
        print_step_header(step, position, total)

        script = Workspace.script_path(step)
        Workspace.ok("running #{step}")
        return true if system(script)

        Workspace.fail_with_help(
          "Start-day workflow stopped before completion.",
          details: "Step '#{step}' failed and subsequent steps were not executed.",
          assumptions: [
            "Each step assumes prior steps completed successfully and prepared the environment.",
            "Continuing after a failed prerequisite step can produce misleading downstream errors."
          ],
          fixes: [
            "Review the logs from the failed step above for the root cause.",
            "Run bin/#{step} directly to troubleshoot that step in isolation.",
            "After fixing the issue, run bin/start-day again."
          ]
        )
        false
      end

      def print_command_header
        title = "Start Day Workflow"
        divider = "=" * 64

        puts
        puts Workspace.pastel.bold(Workspace.pastel.cyan(divider))
        puts Workspace.pastel.bold(Workspace.pastel.cyan(title))
        puts Workspace.pastel.bold(Workspace.pastel.cyan(divider))
        puts
      end

      def print_step_header(step, position, total)
        label = "Step #{position}/#{total}: #{step}"
        divider = "-" * 64

        puts
        puts Workspace.pastel.bold(Workspace.pastel.magenta(label))
        puts Workspace.pastel.dim(divider)
      end

      def maybe_start_dev_services
        return complete_without_dev unless with_dev?

        print_step_header("dev services", WORKFLOW_STEPS.length + 1, WORKFLOW_STEPS.length + 1)
        Workspace.ok("starting development services")
        exec(Workspace.script_path("dev"))
      end

      def with_dev?
        argv.include?("--with-dev")
      end

      def complete_without_dev
        Workspace.ok("start-day complete")
        0
      end
    end
  end
end
