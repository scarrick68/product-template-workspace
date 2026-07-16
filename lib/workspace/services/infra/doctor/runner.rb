# frozen_string_literal: true

module Workspace
  module Services
    module Infra
      module Doctor
        class Runner
          def initialize(checks:)
            @checks = checks
          end

          def call
            failed_checks = []
            checks.each do |check|
              failed_checks << check.label unless check.call
            end

            unless failed_checks.empty?
              Workspace.info("infra doctor failed checks: #{failed_checks.join(', ')}")
              Workspace.fail("infra doctor detected one or more issues")
              return 1
            end

            Workspace.ok("infra doctor checks passed")
            0
          end

          private

          attr_reader :checks
        end
      end
    end
  end
end
