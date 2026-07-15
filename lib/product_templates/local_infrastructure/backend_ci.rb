# frozen_string_literal: true

require_relative "../../workspace"
require_relative "../../workspace/context"
require_relative "port_releaser"

module ProductTemplates
  module LocalInfrastructure
    class BackendCI
      DEFAULT_OPENSEARCH_PORT = 9200

      def initialize(backend_path:, backend_label:, workspace_root:, stdin: $stdin, stdout: $stdout)
        @backend_path = backend_path
        @backend_label = backend_label
        @workspace_root = workspace_root
        @stdin = stdin
        @stdout = stdout
      end

      def prepare
        return true unless applicable?
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

      def start_opensearch
        Workspace.info("Ensuring backend CI infrastructure is running (opensearch)")

        Workspace.run(
          "docker compose up -d opensearch",
          chdir: backend_path,
          allow_failure: true,
          summary: "Could not start backend OpenSearch infrastructure for CI.",
          details: "docker compose failed in #{backend_label}.",
          fixes: [
            "Run docker compose up -d opensearch manually inside #{backend_label}.",
            "Resolve compose errors, then rerun the validation command.",
            "If host port #{opensearch_port} is already in use, stop the conflicting service first."
          ]
        )
      end

      def port_releaser
        @port_releaser ||= PortConflictResolver.new(input: stdin, output: stdout)
      end
    end
  end
end
