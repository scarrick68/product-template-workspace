# frozen_string_literal: true

require_relative "../../workspace"
require_relative "../../workspace/context"
require_relative "port_releaser"

module ProductTemplates
  module LocalInfrastructure
    class BackendCI
      DEFAULT_OPENSEARCH_PORT = 9200
      DOCKER_DAEMON_WAIT_ATTEMPTS = 30
      DOCKER_DAEMON_WAIT_INTERVAL = 1

      def initialize(backend_path:, backend_label:, workspace_root:, stdin: $stdin, stdout: $stdout)
        @backend_path = backend_path
        @backend_label = backend_label
        @workspace_root = workspace_root
        @stdin = stdin
        @stdout = stdout
      end

      def prepare
        return true unless applicable?
        return false unless docker_daemon_running?
        return false unless port_releaser.resolve(opensearch_port, service_name: "OpenSearch")

        start_opensearch
      end

      private

      attr_reader :backend_path, :backend_label, :workspace_root, :stdin, :stdout

      def applicable?
        File.exist?(compose_file) && Workspace.command_exists?("docker")
      end

      def compose_file
        File.join(backend_path, "compose.yml")
      end

      def opensearch_port
        context = Workspace::Context.new(root: workspace_root)
        value = Workspace.ports(context: context).fetch("opensearch", DEFAULT_OPENSEARCH_PORT)
        Integer(value)
      rescue ArgumentError, TypeError
        DEFAULT_OPENSEARCH_PORT
      end

      def docker_daemon_running?
        return true if Workspace.ensure_docker_daemon_running(
          wait_attempts: DOCKER_DAEMON_WAIT_ATTEMPTS,
          wait_interval: DOCKER_DAEMON_WAIT_INTERVAL,
          launch_message: "Docker daemon is not running. Attempting to start Docker Desktop in background.",
          summary: "Could not start Docker Desktop.",
          details: "The command 'open -g -a Docker' failed.",
          fixes: [
            "Launch Docker Desktop manually from Applications.",
            "Wait until 'docker info' succeeds.",
            "Re-run the validation command once Docker is running."
          ]
        )

        Workspace.fail_with_help(
          "Docker is installed but the daemon is not running.",
          details: "Backend CI requires Docker daemon access before running 'docker compose up -d opensearch' in #{backend_label}.",
          assumptions: [
            "OpenSearch is started with docker compose as part of API CI preparation.",
            "When Docker daemon is stopped, compose commands cannot start required services."
          ],
          fixes: [
            "Start Docker Desktop (or your Docker daemon service).",
            "Wait until 'docker info' succeeds.",
            "Re-run the validation command once Docker is running."
          ]
        )

        false
      end

      def start_opensearch
        Workspace.info("Ensuring backend CI infrastructure is running (opensearch)")

        return true if run_compose_up

        unless docker_daemon_available?
          recovered = Workspace.ensure_docker_daemon_running(
            wait_attempts: DOCKER_DAEMON_WAIT_ATTEMPTS,
            wait_interval: DOCKER_DAEMON_WAIT_INTERVAL,
            launch_message: "Docker daemon became unavailable while preparing OpenSearch. Attempting to start Docker Desktop in background.",
            summary: "Could not start Docker Desktop.",
            details: "The command 'open -g -a Docker' failed.",
            fixes: [
              "Launch Docker Desktop manually from Applications.",
              "Wait until 'docker info' succeeds.",
              "Re-run the validation command once Docker is running."
            ]
          )

          if recovered
            Workspace.info("Retrying OpenSearch compose startup after Docker daemon recovery.")
            return true if run_compose_up
          end
        end

        Workspace.fail_with_help(
          "Could not start backend OpenSearch infrastructure for CI.",
          details: "docker compose failed in #{backend_label}.",
          assumptions: [
            "The command 'docker compose up -d opensearch' is valid and available in PATH.",
            "The working directory exists and has the expected project files: #{backend_path}.",
            "Your environment has required credentials and network access for this command."
          ],
          fixes: [
            "Run docker compose up -d opensearch manually inside #{backend_label}.",
            "Resolve compose errors, then rerun the validation command.",
            "If host port #{opensearch_port} is already in use, stop the conflicting service first.",
            "If logs show 'indexCreatedVersionMajor is in the future', reset local OpenSearch data: docker compose down -v && docker compose up -d opensearch.",
            "For disposable local dev data only: remove volume '#{File.basename(backend_path)}_opensearch_data' and restart compose."
          ]
        )

        false
      end

      def run_compose_up
        command = "docker compose up -d opensearch"
        puts Workspace.pastel.cyan("$ #{command}")

        output, success = Workspace.capture(command, chdir: backend_path)
        puts output unless output.to_s.strip.empty?

        success
      end

      def docker_daemon_available?
        _out, running = Workspace.capture("docker info")
        running
      end

      def port_releaser
        @port_releaser ||= PortConflictResolver.new(input: stdin, output: stdout)
      end
    end
  end
end
