# frozen_string_literal: true

require "timeout"

require_relative "./vike_app_reachability_check"
require_relative "./keystatic_admin_reachability_check"

module ProductTemplates
  module Validation
    class ContentReachability
      DEFAULT_VIKE_URL = "http://127.0.0.1:3000"
      DEFAULT_CMS_URL = "http://127.0.0.1:4322/keystatic"
      SHUTDOWN_TIMEOUT_SECONDS = 5
      VALID_TARGETS = %i[all vike keystatic].freeze

      def initialize(
        root:,
        target: :all,
        vite_url: DEFAULT_VIKE_URL,
        cms_url: DEFAULT_CMS_URL,
        stdout: $stdout,
        stderr: $stderr
      )
        @root = root
        @target = target.to_sym
        @vite_url = vite_url
        @cms_url = cms_url
        @stdout = stdout
        @stderr = stderr
        @pids = []
        @cleaned_up = false
      end

      def call
        validate!

        success = case target
                  when :vike
                    start_process(%w[npm run dev])
                    vike_reachability.call
                  when :keystatic
                    start_process(%w[npm run content])
                    keystatic_reachability.call
                  else
                    start_process(%w[npm run dev])
                    start_process(%w[npm run content])
                    vike_reachability.call && keystatic_reachability.call
                  end

        stdout.puts("[ok] local CMS dev/content wiring verification passed") if success
        success
      ensure
        cleanup
      end

      private

      attr_reader :root, :target, :vite_url, :cms_url, :stdout, :stderr, :pids

      def validate!
        return if VALID_TARGETS.include?(target)

        raise ArgumentError, "target must be one of: #{VALID_TARGETS.join(', ')}"
      end

      def start_process(command)
        pid = spawn(*command, chdir: root, pgroup: true, out: File::NULL, err: File::NULL)
        pids << pid
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

        pids.reverse_each { |pid| terminate_process_group(pid, "TERM") }
        pids.reverse_each { |pid| wait_for_process(pid) }
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
      rescue Errno::ESRCH
        nil
      end

      def reap_process(pid)
        Process.wait(pid)
      rescue Errno::ECHILD
        nil
      end
    end
  end
end
