# frozen_string_literal: true

require_relative "adapters/env"
require_relative "adapters/macos_keychain"
require_relative "adapters/unsupported_keychain"

module Workspace
  module Secrets
    # Builds secret storage adapters based on the current runtime platform.
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
    end
  end
end