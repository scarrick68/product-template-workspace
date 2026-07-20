# frozen_string_literal: true

require "json"
require "open3"
require_relative "../../../workspace"

module Workspace
  module Infrastructure
    module DigitalOcean
      # Base error type for DigitalOcean resource management operations.
      class Error < StandardError; end

      # Minimal doctl wrapper for command execution and JSON decoding.
      class Client
        def json(*arguments)
          output, status = Open3.capture2e(
            "doctl",
            *arguments,
            "--output",
            "json",
            chdir: Workspace::ROOT
          )

          raise Error, command_error(arguments, output) unless status.success?

          JSON.parse(output)
        rescue JSON::ParserError => e
          raise Error, "doctl returned invalid JSON: #{e.message}"
        end

        def run(*arguments)
          output, status = Open3.capture2e(
            "doctl",
            *arguments,
            chdir: Workspace::ROOT
          )

          raise Error, command_error(arguments, output) unless status.success?

          output
        end

        private

        def command_error(arguments, output)
          <<~MESSAGE
            DigitalOcean command failed:
              doctl #{arguments.join(" ")}

            #{output}
          MESSAGE
        end
      end
    end
  end
end
