# frozen_string_literal: true

require_relative "factory"

module Workspace
  module Secrets
    class WorkspaceCredentialsStore
      class Error < StandardError; end

      def require_available!(message: "Workspace credentials must be initialized before continuing.")
        return if adapter.available? && adapter.writable?

        raise Error, message
      end

      def read_hash(key)
        value = adapter.read(key)
        value.is_a?(Hash) ? value : nil
      rescue StandardError
        nil
      end

      def write_hash!(key, value, message: "Could not save credentials.")
        raise Error, message unless adapter.write(key, value)

        true
      end

      private

      def adapter
        @adapter ||= Factory.workspace_credentials_adapter
      end
    end
  end
end