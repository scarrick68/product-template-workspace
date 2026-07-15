# frozen_string_literal: true

require "tty-prompt"

require_relative "../../workspace"

module ProductTemplates
  module LocalInfrastructure
    class PortConflictResolver
      WAIT_ATTEMPTS = 20
      WAIT_INTERVAL = 0.3

      Container = Data.define(:id, :name)

      PortUsage = Data.define(:port, :process_ids, :containers) do
        def available?
          process_ids.empty? && containers.empty?
        end

        def description
          [
            process_description,
            container_description
          ].compact.join(" | ")
        end

        private

        def process_description
          return if process_ids.empty?

          "processes: #{process_ids.join(', ')}"
        end

        def container_description
          return if containers.empty?

          "containers: #{containers.map(&:name).join(', ')}"
        end
      end

      def initialize(
        input: $stdin,
        output: $stdout,
        prompt: TTY::Prompt.new(input: input, output: output)
      )
        @input = input
        @prompt = prompt
      end

      def resolve(port, service_name:)
        port = Integer(port)
        usage = port_usage(port)

        return true if usage.available?
        return declined(port, service_name) unless confirm_cleanup?(usage, service_name)

        stop_containers(usage.containers)
        stop_processes(usage.process_ids)

        return true if wait_until_available(port)

        cleanup_failed(port, service_name)
      end

      private

      attr_reader :input, :prompt

      def confirm_cleanup?(usage, service_name)
        Workspace.warn(
          "#{service_name} cannot start because port #{usage.port} is in use."
        )
        Workspace.info("Blocking #{usage.description}.")

        return false unless interactive?

        prompt.yes?(
          "Stop these services and free port #{usage.port}?",
          default: true
        )
      rescue TTY::Reader::InputInterrupt, TTY::Reader::EOFError
        false
      end

      def interactive?
        input.respond_to?(:tty?) && input.tty?
      end

      def port_usage(port)
        PortUsage.new(
          port: port,
          process_ids: listening_process_ids(port),
          containers: containers_publishing(port)
        )
      end

      def listening_process_ids(port)
        output, success = Workspace.capture(
          "lsof -tiTCP:#{port} -sTCP:LISTEN"
        )
        return [] unless success

        output.lines.filter_map do |line|
          Integer(line.strip)
        rescue ArgumentError
          nil
        end
      end

      def containers_publishing(port)
        output, success = Workspace.capture(
          "docker ps --format '{{.ID}}|{{.Names}}' --filter publish=#{port}"
        )
        return [] unless success

        output.lines.filter_map do |line|
          id, name = line.strip.split("|", 2)
          next if id.to_s.empty? || name.to_s.empty?

          Container.new(id: id, name: name)
        end
      end

      def stop_containers(containers)
        containers.each do |container|
          stop_container(container)
        end
      end

      def stop_container(container)
        Workspace.run(
          "docker stop #{container.id}",
          allow_failure: true,
          summary: "Could not stop container #{container.name}.",
          details: "#{container.name} is using a port required by local CI.",
          fixes: [
            "Stop the container manually: docker stop #{container.id}",
            "Then rerun the validation command."
          ]
        )
      end

      def stop_processes(process_ids)
        process_ids.each do |process_id|
          stop_process(process_id)
        end
      end

      def stop_process(process_id)
        Process.kill("TERM", process_id)
      rescue Errno::ESRCH
        nil
      rescue Errno::EPERM
        Workspace.warn(
          "Cannot stop process #{process_id} without additional permissions."
        )
      end

      def wait_until_available(port)
        WAIT_ATTEMPTS.times do
          return true if port_usage(port).available?

          sleep WAIT_INTERVAL
        end

        port_usage(port).available?
      end

      def declined(port, service_name)
        Workspace.fail_with_help(
          "#{service_name} cannot start because port #{port} is in use.",
          details: "Automatic cleanup was not approved or no interactive terminal is available.",
          fixes: [
            "Inspect the port: lsof -nP -iTCP:#{port} -sTCP:LISTEN",
            "Stop the blocking process or container.",
            "Then rerun the validation command."
          ]
        )

        false
      end

      def cleanup_failed(port, service_name)
        Workspace.fail_with_help(
          "Could not free port #{port} for #{service_name}.",
          details: "The port is still in use after cleanup was attempted.",
          fixes: [
            "Inspect the port: lsof -nP -iTCP:#{port} -sTCP:LISTEN",
            "Inspect containers: docker ps --filter publish=#{port}",
            "Stop the remaining blocker and rerun the validation command."
          ]
        )

        false
      end
    end
  end
end