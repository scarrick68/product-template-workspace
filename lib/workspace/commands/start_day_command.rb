#!/usr/bin/env ruby
# frozen_string_literal: true
# Command object for running the daily workflow orchestration.

require_relative "../../workspace"

module Workspace
  module Commands
    class StartDayCommand
      WORKFLOW_STEPS = [
        "preinstall",
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
        return 1 unless run_workflow_steps

        maybe_start_dev_services
      end

      private

      attr_reader :argv

      def run_workflow_steps
        WORKFLOW_STEPS.each do |step|
          return false unless run_step(step)
        end

        true
      end

      def run_step(step)
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

      def maybe_start_dev_services
        return complete_without_dev unless with_dev?

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
