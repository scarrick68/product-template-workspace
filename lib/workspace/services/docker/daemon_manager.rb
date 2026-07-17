# frozen_string_literal: true

module Workspace
  module Services
    module Docker
      # Ensures the Docker daemon is ready, optionally launching Docker Desktop.
      class DaemonManager
        DEFAULT_WAIT_ATTEMPTS = 30
        DEFAULT_WAIT_INTERVAL = 1

        def initialize(workspace:)
          @workspace = workspace
        end

        def docker_daemon_running?
          _output, success = workspace.capture("docker info")
          success
        end

        def ensure_docker_daemon_running(
          wait_attempts: DEFAULT_WAIT_ATTEMPTS,
          wait_interval: DEFAULT_WAIT_INTERVAL,
          launch_message: nil,
          launch_if_not_running: true,
          summary: "Could not start Docker Desktop.",
          details: "The command 'open -g -a Docker' failed.",
          fixes: []
        )
          return true if docker_daemon_running?
          return false if launch_if_not_running && !docker_desktop_available?
          return wait_for_docker_daemon(wait_attempts: wait_attempts, wait_interval: wait_interval) unless launch_if_not_running

          if docker_desktop_app_running?
            return wait_for_docker_daemon(
              wait_attempts: wait_attempts,
              wait_interval: wait_interval
            )
          end

          workspace.info(launch_message) if launch_message

          launched = workspace.run(
            "open -g -a Docker",
            allow_failure: true,
            summary: summary,
            details: details,
            fixes: fixes
          )

          return false unless launched

          wait_for_docker_daemon(
            wait_attempts: wait_attempts,
            wait_interval: wait_interval
          )
        end

        private

        attr_reader :workspace

        def wait_for_docker_daemon(wait_attempts:, wait_interval:)
          wait_attempts.times do
            return true if docker_daemon_running?

            sleep wait_interval
          end

          false
        end

        def docker_desktop_app_running?
          return false unless macos?

          _output, success = workspace.capture("pgrep -x Docker")
          success
        end

        def docker_desktop_available?
          macos? && workspace.command_exists?("open")
        end

        def macos?
          RUBY_PLATFORM.include?("darwin")
        end
      end
    end
  end
end
