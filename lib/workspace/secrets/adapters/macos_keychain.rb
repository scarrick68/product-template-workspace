# frozen_string_literal: true

require "open3"
require "shellwords"
require_relative "base"

module Workspace
  module Secrets
    module Adapters
      # Integrates with the macOS security CLI for keychain-backed secret storage.
      class MacosKeychain < Base
        SERVICE = "product-template-workspace".freeze

        def initialize(service: SERVICE)
          @service = service
        end

        def available?
          RUBY_PLATFORM.include?("darwin") && system("command -v security >/dev/null 2>&1")
        end

        def read(key)
          return nil unless available?

          command = [
            "security",
            "find-generic-password",
            "-s",
            @service,
            "-a",
            key,
            "-w"
          ]

          output, status = Open3.capture2e(*command)
          return nil unless status.success?

          token = output.to_s.strip
          token.empty? ? nil : token
        end

        def write(key, value)
          return false unless available?

          command = [
            "security",
            "add-generic-password",
            "-s",
            @service,
            "-a",
            key,
            "-w",
            value,
            "-U"
          ]

          _output, status = Open3.capture2e(*command)
          status.success?
        end

        def writable?
          true
        end

        def name
          "Apple Keychain"
        end
      end
    end
  end
end