# frozen_string_literal: true

module ProductTemplates
  module Validation
    class Report
      def print(results)
        print_checklist(results)
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
    end
  end
end
