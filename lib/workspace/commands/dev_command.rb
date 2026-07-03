#!/usr/bin/env ruby
# frozen_string_literal: true
# Command object for launching and supervising local development services.

require_relative "../../workspace"

module Workspace
  module Commands
    class DevCommand
      STOP_WAIT_ATTEMPTS = 20
      STOP_WAIT_INTERVAL = 0.3
      START_WAIT_ATTEMPTS = 25
      START_WAIT_INTERVAL = 0.35

      def initialize
        @ports = Workspace.ports
        @services = []
        @running_services = {}
        @service_outcomes = {}
      end

      def call
        build_services
        return 1 unless services_available?

        install_interrupt_handler
        return 1 unless start_services

        if running_services.empty?
          Workspace.warn("No new services were started. Existing services may still be running.")
          return 0
        end

        print_runtime_stop_hint

        monitor_services
      end

      private

      attr_reader :ports, :services, :running_services, :service_outcomes

      def build_services
        add_api_service
        add_web_service
      end

      def add_api_service
        api_repo = File.join(Workspace::ROOT, "repos", "api-template")
        api_port = ports.fetch("api", 5001)

        if File.executable?(File.join(api_repo, "bin", "dev"))
          services << {
            name: "API",
            chdir: api_repo,
            command: "bin/dev",
            port: api_port,
            env: {
              "PORT" => api_port.to_s
            }
          }
          return
        end

        return unless File.executable?(File.join(api_repo, "bin", "rails"))

        services << {
          name: "API",
          chdir: api_repo,
          command: "bundle exec rails server -p #{api_port}",
          port: api_port
        }
      end

      def add_web_service
        web_repo = File.join(Workspace::ROOT, "repos", "web-template")
        return unless File.exist?(File.join(web_repo, "package.json"))

        web_port = ports.fetch("web", 3000)
        api_port = ports.fetch("api", 5001)
        rails_proxy_target = ENV.fetch("VITE_RAILS_PROXY_TARGET", "http://localhost:#{api_port}")

        services << {
          name: "WEB",
          chdir: web_repo,
          command: "npm run dev -- --port #{web_port}",
          port: web_port,
          env: {
            "VITE_RAILS_PROXY_TARGET" => rails_proxy_target
          }
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
          preparation = prepare_service_for_start(service)
          if preparation == :skip
            record_outcome(service[:name], :reused, "launch skipped; existing process retained")
            next
          end
          return false unless preparation == :ready

          Workspace.ok("starting #{service[:name]} (#{service[:command]})")
          # Run each service in its own process group so TERM can cascade to descendants.
          service_env = service[:env] || {}
          pid = Process.spawn(service_env, service[:command], chdir: service[:chdir], pgroup: true, out: $stdout, err: $stderr)
          running_services[service[:name]] = service.merge(pid: pid)
          report_start_readiness(service)
        rescue StandardError => e
          Workspace.fail_with_help(
            "Failed to start #{service[:name]} service.",
            details: "Could not spawn '#{service[:command]}' in #{service[:chdir]}: #{e.class}: #{e.message}",
            assumptions: [
              "Service command exists and is executable in the configured repository path.",
              "Required runtime dependencies and environment variables are available."
            ],
            fixes: [
              "Run the service command manually in #{service[:chdir]} to inspect startup errors.",
              "Install missing dependencies and verify environment setup.",
              "Fix the error and rerun bin/dev or bin/start-day --with-dev."
            ]
          )
          stop_all_services
          return false
        end

        print_service_outcomes
        true
      end

      def monitor_services
        pid, status = Process.wait2
      rescue Errno::ECHILD
        Workspace.fail_with_help(
          "No child processes are available to monitor.",
          details: "All spawned services exited before monitoring began, or no services were started.",
          assumptions: [
            "At least one dev service process should remain running after startup.",
            "Immediate process exit often indicates startup configuration or dependency problems."
          ],
          fixes: [
            "Review startup output above for first-failure details.",
            "Run individual service start commands manually to diagnose.",
            "Fix startup issues and rerun bin/dev."
          ]
        )
        return 1

      else
        service_name = service_name_for_pid(pid)
        exit_code = if status.exited?
                      status.exitstatus
                    elsif status.signaled?
                      128 + status.termsig
                    else
                      1
                    end

        if status.success?
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

      def prepare_service_for_start(service)
        return :skip unless ensure_service_port_available(service)
        return :ready unless service[:name] == "API"

        ensure_api_pid_file_is_safe(service[:chdir]) ? :ready : :skip
      end

      def ensure_api_pid_file_is_safe(api_repo)
        pid_file = File.join(api_repo, "tmp", "pids", "server.pid")
        return true unless File.exist?(pid_file)

        pid = parse_pid_file(pid_file)
        return remove_stale_pid_file(pid_file) if pid.nil?

        return remove_stale_pid_file(pid_file) unless process_running?(pid)

        Workspace.warn("API appears to already be running (pid #{pid}). Attempting graceful restart.")
        return remove_stale_pid_file(pid_file) if gracefully_stop_process(pid)

        Workspace.warn(
          "API did not restart. Existing process pid #{pid} is still active; manual restart is recommended for a fresh environment."
        )
        false
      end

      def remove_stale_pid_file(pid_file)
        File.delete(pid_file) if File.exist?(pid_file)
        Workspace.warn("Removed stale API pid file: #{pid_file}")
        true
      rescue StandardError => e
        Workspace.fail_with_help(
          "Could not remove stale API pid file.",
          details: "Failed to delete #{pid_file}: #{e.class}: #{e.message}",
          assumptions: [
            "The current user has file permissions to modify tmp/pids files.",
            "PID file cleanup is required before Rails server startup can proceed."
          ],
          fixes: [
            "Remove the pid file manually and rerun the command.",
            "Fix filesystem permissions if deletion is denied.",
            "Ensure no active Rails process is using the pid file."
          ]
        )
        false
      end

      def parse_pid_file(pid_file)
        content = File.read(pid_file).strip
        return nil if content.empty?

        Integer(content)
      rescue ArgumentError, TypeError, Errno::ENOENT
        nil
      end

      def process_running?(pid)
        Process.kill(0, pid)
        true
      rescue Errno::ESRCH
        false
      rescue Errno::EPERM
        true
      end

      def ensure_service_port_available(service)
        port = service[:port]
        return true unless port

        pids = listening_pids_for_port(port)
        return true if pids.empty?

        Workspace.warn(
          "#{service[:name]} port #{port} already has running process(es): #{pids.join(', ')}. Attempting graceful restart."
        )

        stop_ok = pids.all? { |pid| gracefully_stop_process(pid) }
        return true if stop_ok && listening_pids_for_port(port).empty?

        remaining_pids = listening_pids_for_port(port)
        if remaining_pids.any?
          Workspace.warn(
            "#{service[:name]} did not restart. Existing process(es) still listening on port #{port}: #{remaining_pids.join(', ')}."
          )
          return false
        end

        Workspace.warn(
          "Could not fully free port #{port} for #{service[:name]}. " \
          "Skipping launch of a duplicate process. Manual restart may be required for a fresh environment."
        )
        false
      end

      def listening_pids_for_port(port)
        output, ok = Workspace.capture("lsof -tiTCP:#{port} -sTCP:LISTEN")
        return [] unless ok

        output.lines.map(&:strip).reject(&:empty?).map { |line| Integer(line) }
      rescue ArgumentError
        []
      end

      def gracefully_stop_process(pid)
        Process.kill("TERM", pid)
      rescue Errno::ESRCH
        return true
      rescue Errno::EPERM
        return false
      rescue StandardError
        false
      else
        STOP_WAIT_ATTEMPTS.times do
          return true unless process_running?(pid)

          sleep STOP_WAIT_INTERVAL
        end

        !process_running?(pid)
      end

      def report_start_readiness(service)
        port = service[:port]
        unless port
          record_outcome(service[:name], :started, "started (no port check configured)")
          return
        end

        if wait_for_port_listener(port)
          Workspace.ok("#{service[:name]} is listening on port #{port}")
          record_outcome(service[:name], :started, "started and listening on port #{port}")
          return
        end

        Workspace.warn(
          "#{service[:name]} started but is not listening on port #{port} yet. " \
          "Startup may still be in progress; check service logs above."
        )
        record_outcome(service[:name], :starting, "spawned, but port #{port} was not ready within #{start_wait_seconds}s")
      end

      def wait_for_port_listener(port)
        START_WAIT_ATTEMPTS.times do
          return true unless listening_pids_for_port(port).empty?

          sleep START_WAIT_INTERVAL
        end

        false
      end

      def start_wait_seconds
        (START_WAIT_ATTEMPTS * START_WAIT_INTERVAL).round(1)
      end

      def record_outcome(service_name, state, detail)
        service_outcomes[service_name] = { state: state, detail: detail }
      end

      def print_service_outcomes
        return if service_outcomes.empty?

        puts
        Workspace.ok("Service status summary:")
        services.each do |service|
          outcome = service_outcomes[service[:name]]
          next unless outcome

          label = "#{service[:name]}: #{outcome[:detail]}"
          if outcome[:state] == :started
            Workspace.ok(label)
          else
            Workspace.warn(label)
          end
        end
      end

      def print_runtime_stop_hint
        return if running_services.empty?

        puts
        Workspace.ok("Development services are running.")
        Workspace.info("Press Ctrl-C in this terminal to stop all services started by this command.")

        running_services.each_value do |service|
          next unless service[:port]

          Workspace.ok("#{service[:name]} URL: http://localhost:#{service[:port]}")
        end
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
