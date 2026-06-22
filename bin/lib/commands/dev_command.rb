#!/usr/bin/env ruby
# frozen_string_literal: true
# Command object for launching and supervising local development services.

require_relative "../workspace"

module Workspace
  module Commands
    class DevCommand
      def initialize
        @ports = Workspace.ports
        @services = []
        @running_services = {}
      end

      def call
        build_services
        return 1 unless services_available?

        install_interrupt_handler
        start_services
        monitor_services
      end

      private

      attr_reader :ports, :services, :running_services

      def build_services
        add_api_service
        add_web_service
      end

      def add_api_service
        api_repo = File.join(Workspace::ROOT, "repos", "api-template")

        if File.executable?(File.join(api_repo, "bin", "dev"))
          services << {
            name: "API",
            chdir: api_repo,
            command: "bin/dev"
          }
          return
        end

        return unless File.executable?(File.join(api_repo, "bin", "rails"))

        services << {
          name: "API",
          chdir: api_repo,
          command: "bundle exec rails server -p #{ports.fetch('api', 5000)}"
        }
      end

      def add_web_service
        web_repo = File.join(Workspace::ROOT, "repos", "web-template")
        return unless File.exist?(File.join(web_repo, "package.json"))

        services << {
          name: "WEB",
          chdir: web_repo,
          command: "npm run dev -- --port #{ports.fetch('web', 3000)}"
        }
      end

      def services_available?
        return true unless services.empty?

        Workspace.fail_with_help(
          "No runnable development services were discovered.",
          details: "Neither API nor WEB start conditions matched available files/scripts.",
          assumptions: [
            "Development orchestration assumes standard repository layout and startup scripts.",
            "Missing entrypoints usually indicate incomplete checkout or setup."
          ],
          fixes: [
            "Verify repos/api-template and repos/web-template exist.",
            "Ensure api-template has bin/dev or bin/rails and web-template has package.json.",
            "Run bin/bootstrap to install dependencies and clone missing repositories."
          ]
        )
        false
      end

      def install_interrupt_handler
        trap("INT") do
          Workspace.warn("interrupt received, stopping services")
          stop_all_services
          exit 130
        end
      end

      def start_services
        services.each do |service|
          Workspace.ok("starting #{service[:name]} (#{service[:command]})")
          # Run each service in its own process group so TERM can cascade to descendants.
          pid = Process.spawn(service[:command], chdir: service[:chdir], pgroup: true, out: $stdout, err: $stderr)
          running_services[service[:name]] = service.merge(pid: pid)
        end
      end

      def monitor_services
        pid = Process.wait
        service_name = service_name_for_pid(pid)
        exit_code = $CHILD_STATUS.exitstatus

        if exit_code.zero?
          Workspace.warn("#{service_name} exited normally, stopping remaining services")
        else
          Workspace.fail_with_help(
            "#{service_name} process exited unexpectedly.",
            details: "The service returned exit code #{exit_code}; remaining services are being stopped to avoid partial environment state.",
            assumptions: [
              "Service startup assumes dependencies are installed and required ports/services are available.",
              "An early non-zero exit usually indicates a config, dependency, or port conflict."
            ],
            fixes: [
              "Inspect logs directly above for the first error from #{service_name}.",
              "Fix dependency, port, or configuration problems in that repository.",
              "Re-run bin/dev after the failing service starts successfully."
            ]
          )
        end

        stop_all_services(except_pid: pid)
        1
      end

      def stop_all_services(except_pid: nil)
        running_services.each_value do |service|
          next if service[:pid] == except_pid

          stop_service_process_group(service)
        end
      end

      def stop_service_process_group(service)
        pid = service[:pid]
        return unless pid

        pgid = Process.getpgid(pid)
        Process.kill("TERM", -pgid)
      rescue Errno::ESRCH
        nil
      end

      def service_name_for_pid(pid)
        service = running_services.values.find { |entry| entry[:pid] == pid }
        service ? service[:name] : "UNKNOWN"
      end
    end
  end
end
