# frozen_string_literal: true

require "net/http"
require "uri"

module ProductTemplates
  module Validation
    class KeystaticAdminReachabilityCheck
      DEFAULT_TIMEOUT_SECONDS = 30
      DEFAULT_POLL_INTERVAL_SECONDS = 1.0

      def initialize(
        url:,
        timeout_seconds: DEFAULT_TIMEOUT_SECONDS,
        poll_interval_seconds: DEFAULT_POLL_INTERVAL_SECONDS,
        stdout: $stdout,
        stderr: $stderr
      )
        @url = url
        @timeout_seconds = timeout_seconds
        @poll_interval_seconds = poll_interval_seconds
        @stdout = stdout
        @stderr = stderr
      end

      def call
        wait_for_url(url: url, label: "keystatic admin")
      end

      private

      attr_reader :url, :timeout_seconds, :poll_interval_seconds, :stdout, :stderr

      def http_ok?
        uri = URI(url)
        request_path = uri.request_uri.empty? ? "/" : uri.request_uri

        response = Net::HTTP.start(
          uri.host,
          uri.port,
          use_ssl: uri.scheme == "https",
          open_timeout: 2,
          read_timeout: 2
        ) do |http|
          http.request(Net::HTTP::Get.new(request_path))
        end

        response.is_a?(Net::HTTPSuccess) || response.is_a?(Net::HTTPRedirection)
      rescue StandardError
        false
      end

      def wait_for_url(url:, label:)
        deadline = Time.now + timeout_seconds

        loop do
          if http_ok?
            stdout.puts "[ok] #{label} reachable: #{url}"
            return true
          end

          if Time.now >= deadline
            stderr.puts "[error] #{label} not reachable: #{url}"
            return false
          end

          sleep(poll_interval_seconds)
        end
      end
    end
  end
end
