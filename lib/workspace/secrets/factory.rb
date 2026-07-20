# frozen_string_literal: true

require_relative "adapters/env"
require_relative "adapters/macos_keychain"
require_relative "adapters/unsupported_keychain"
require_relative "adapters/workspace_credentials"

module Workspace
  module Secrets
    class Factory
      def self.env_adapter
        Adapters::Env.new
      end

      def self.keychain_adapter(platform: RUBY_PLATFORM)
        if platform.include?("darwin")
          Adapters::MacosKeychain.new
        else
          Adapters::UnsupportedKeychain.new
        end
      end

      def self.workspace_credentials_adapter
        Adapters::WorkspaceCredentials.new
      end
    end
  end
end