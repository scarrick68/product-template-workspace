# frozen_string_literal: true

require_relative "result"

module Workspace
  module Secrets
    class Store
      def initialize(env_adapter:, keychain_adapter:)
        @env_adapter = env_adapter
        @keychain_adapter = keychain_adapter
      end

      def read(key)
        env_value = @env_adapter.read(key).to_s.strip
        return Result.new(value: env_value, source: @env_adapter.name) unless env_value.empty?

        return Result.new(value: nil, source: nil) unless @keychain_adapter.available?

        keychain_value = @keychain_adapter.read(key).to_s.strip
        return Result.new(value: keychain_value, source: @keychain_adapter.name) unless keychain_value.empty?

        Result.new(value: nil, source: nil)
      end

      def write(key, value)
        return false unless @keychain_adapter.available?
        return false unless @keychain_adapter.writable?

        @keychain_adapter.write(key, value)
      end

      def keychain_adapter
        @keychain_adapter
      end
    end
  end
end