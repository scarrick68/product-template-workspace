# frozen_string_literal: true

require "tempfile"
require "timeout"
require "uri"

require_relative "../local_infrastructure/port_releaser"
require_relative "./vike_app_reachability_check"
require_relative "./keystatic_admin_reachability_check"

module ProductTemplates
  module Validation
    class ContentReachability
      DEFAULT_VIKE_URL = "http://127.0.0.1:3000"
      DEFAULT_CMS_URL = "http://127.0.0.1:4322/keystatic"
      SHUTDOWN_TIMEOUT_SECONDS = 5
      VALID_TARGETS = %i[all vike keystatic].freeze
      ProcessHandle = Data.define(:pid, :label, :log)

      def initialize(
        root:,
        target: :all,
        vite_url: DEFAULT_VIKE_URL,
        cms_url: DEFAULT_CMS_URL,
        stdin: $stdin,
        stdout: $stdout,
        stderr: $stderr
      )
        @root = root
        @target = target.to_sym
        @vite_url = vite_url
        @cms_url = cms_url
        @stdin = stdin
        @stdout = stdout
        @stderr = stderr
        @processes = []
        @cleaned_up = false
      end

      def call
        validate!

        success = case target
                  when :vike
                    verify_vike
                  when :keystatic
                    verify_keystatic
                  else
                    verify_all
                  end

        stdout.puts("[ok] local CMS dev/content wiring verification passed") if success
        success
      ensure
        cleanup
      end

      private

      attr_reader :root, :target, :vite_url, :cms_url, :stdin, :stdout, :stderr, :processes

      def validate!
        return if VALID_TARGETS.include?(target)

        raise ArgumentError, "target must be one of: #{VALID_TARGETS.join(', ')}"
      end

      def verify_vike
        return false unless ensure_vike_port_available

        process = start_process(vike_dev_command, label: "Vike dev server")

        vike_reachability.call(
          process_alive: -> { process_alive?(process) },
          process_failure: -> { report_process_failure(process) }
        )
      end

      def verify_keystatic
        process = start_process(%w[npm run content], label: "Keystatic dev server")

        keystatic_reachability.call(
          process_alive: -> { process_alive?(process) },
          process_failure: -> { report_process_failure(process) }
        )
      end

      def verify_all
        return false unless ensure_vike_port_available

        vike_process = start_process(vike_dev_command, label: "Vike dev server")
        keystatic_process = start_process(%w[npm run content], label: "Keystatic dev server")

        vike_reachability.call(
          process_alive: -> { process_alive?(vike_process) },
          process_failure: -> { report_process_failure(vike_process) }
        ) &&
          keystatic_reachability.call(
            process_alive: -> { process_alive?(keystatic_process) },
            process_failure: -> { report_process_failure(keystatic_process) }
          )
      end

      def start_process(command, label:)
        log = Tempfile.new(["content-reachability-", ".log"])
        log.sync = true

        stdout.puts("[info] Starting #{label}: #{command.join(' ')}")

        pid = spawn(*command, chdir: root, pgroup: true, out: log, err: log)
        process = ProcessHandle.new(pid: pid, label: label, log: log)
        processes << process
        process
      end

      def process_alive?(process)
        waited_pid, = Process.waitpid2(process.pid, Process::WNOHANG)
        waited_pid.nil?
      rescue Errno::ECHILD
        false
      end

      def report_process_failure(process)
        stderr.puts("[error] #{process.label} exited before becoming reachable")
        output = process_output(process)
        stderr.puts(output) unless output.empty?
      end

      def process_output(process)
        process.log.flush
        process.log.rewind
        process.log.read.strip
      rescue IOError
        ""
      end

      def ensure_vike_port_available
        port_conflict_resolver.resolve(vike_port, service_name: "Vike dev server")
      end

      def vike_port
        URI(vite_url).port
      rescue URI::InvalidURIError
        3000
      end

      def vike_dev_command
        uri = URI(vite_url)
        host = uri.host || "127.0.0.1"
        port = uri.port || 3000
        ["npm", "run", "dev", "--", "--host", host, "--port", port.to_s]
      rescue URI::InvalidURIError
        ["npm", "run", "dev", "--", "--host", "127.0.0.1", "--port", "3000"]
      end

      def vike_reachability
        @vike_reachability ||= VikeAppReachabilityCheck.new(
          url: vite_url,
          stdout: stdout,
          stderr: stderr
        )
      end

      def keystatic_reachability
        @keystatic_reachability ||= KeystaticAdminReachabilityCheck.new(
          url: cms_url,
          stdout: stdout,
          stderr: stderr
        )
      end

      def cleanup
        return if @cleaned_up

        @cleaned_up = true

        processes.reverse_each { |process| terminate_process_group(process.pid, "TERM") }
        processes.reverse_each do |process|
          wait_for_process(process.pid)
          process.log.close!
        end
      end

      def wait_for_process(pid)
        Timeout.timeout(SHUTDOWN_TIMEOUT_SECONDS) { Process.wait(pid) }
      rescue Timeout::Error
        terminate_process_group(pid, "KILL")
        reap_process(pid)
      rescue Errno::ECHILD
        nil
      end

      def terminate_process_group(pid, signal)
        Process.kill(signal, -pid)
      rescue Errno::ESRCH, Errno::EPERM
        nil
      end

      def reap_process(pid)
        Process.wait(pid)
      rescue Errno::ECHILD
        nil
      end

      def port_conflict_resolver
        @port_conflict_resolver ||= LocalInfrastructure::PortConflictResolver.new(input: stdin, output: stdout)
      end
    end
  end
end
