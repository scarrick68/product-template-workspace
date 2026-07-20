# frozen_string_literal: true

require_relative "result"

module Workspace
  module Secrets
    class Store
      def initialize(env_adapter:, keychain_adapter:, workspace_adapter: nil)
        @env_adapter = env_adapter
        @keychain_adapter = keychain_adapter
        @workspace_adapter = workspace_adapter
      end

      def read(key)
        if @workspace_adapter && @workspace_adapter.available?
          workspace_value = @workspace_adapter.read(key).to_s.strip
          return Result.new(value: workspace_value, source: @workspace_adapter.name) unless workspace_value.empty?
        end

        env_value = @env_adapter.read(key).to_s.strip
        return Result.new(value: env_value, source: @env_adapter.name) unless env_value.empty?

        return Result.new(value: nil, source: nil) unless @keychain_adapter.available?

        keychain_value = @keychain_adapter.read(key).to_s.strip
        return Result.new(value: keychain_value, source: @keychain_adapter.name) unless keychain_value.empty?

        Result.new(value: nil, source: nil)
      end

      def write_workspace(key, value)
        return false unless @workspace_adapter
        return false unless @workspace_adapter.available?
        return false unless @workspace_adapter.writable?

        @workspace_adapter.write(key, value)
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