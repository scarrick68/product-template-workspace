# frozen_string_literal: true

module ProductTemplates
  module Validation
    class Report
      MANUAL_STEPS = [
        "Verify GitHub repo names and remote origins for renamed apps.",
        "Verify deployment app/project names and secrets.",
        "Run bin/sync-openapi and confirm contract consumers still resolve paths.",
        "Smoke test local startup with bin/bootstrap and bin/start-day."
      ].freeze

      def print(results)
        print_checklist(results)
        print_manual_steps
      end

      private

      def print_checklist(results)
        puts
        Workspace.ok("Template -> Product Handoff Checklist")

        results.each do |result|
          marker = result.passed? ? "[x]" : "[ ]"
          puts "  #{marker} #{result.name} (#{result.note})"
        end
      end

      def print_manual_steps
        puts
        Workspace.warn("Manual follow-up required:")

        MANUAL_STEPS.each do |step|
          puts "  [ ] #{step}"
        end
      end
    end
  end
end
