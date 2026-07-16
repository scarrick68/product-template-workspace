# frozen_string_literal: true

require "active_support/encrypted_file"
require "yaml"
require_relative "base"

module Workspace
  module Secrets
    module Adapters
      class WorkspaceCredentials < Base
        KEY_PATH = File.join(Workspace::ROOT, "config", "workspace_credentials.key")
        ENCRYPTED_PATH = File.join(Workspace::ROOT, "config", "workspace_credentials.yml.enc")

        def initialize(key_path: KEY_PATH, encrypted_path: ENCRYPTED_PATH)
          @key_path = key_path
          @encrypted_path = encrypted_path
        end

        def available?
          File.exist?(key_path) && File.exist?(encrypted_path)
        end

        def read(key)
          return nil unless available?

          payload = credentials_data
          return payload[key] if payload.key?(key)

          dig_path(payload, key_path_segments(key))
        rescue StandardError
          nil
        end

        def write(key, value)
          return false unless available?

          payload = credentials_data

          # Keep backward compatibility with existing flat keys (for example
          # "DIGITALOCEAN_ACCESS_TOKEN") while supporting dot-path nesting.
          if payload.key?(key) || !key.to_s.include?(".")
            payload[key] = value
          else
            write_path(payload, key_path_segments(key), value)
          end

          encrypted_file.write(payload.to_yaml)
          true
        rescue StandardError
          false
        end

        def writable?
          available?
        end

        def name
          "workspace credentials"
        end

        private

        attr_reader :key_path, :encrypted_path

        def encrypted_file
          @encrypted_file ||= ActiveSupport::EncryptedFile.new(
            content_path: encrypted_path,
            key_path: key_path,
            env_key: "UNUSED_WORKSPACE_CREDENTIALS_KEY",
            raise_if_missing_key: false
          )
        end

        def credentials_data
          raw = encrypted_file.read
          parsed = YAML.safe_load(raw.to_s, permitted_classes: [], aliases: false)
          parsed.is_a?(Hash) ? parsed : {}
        rescue StandardError
          {}
        end

        def key_path_segments(key)
          key.to_s.split(".").map(&:strip).reject(&:empty?)
        end

        def dig_path(payload, segments)
          segments.reduce(payload) do |memo, segment|
            break nil unless memo.is_a?(Hash)

            memo[segment]
          end
        end

        def write_path(payload, segments, value)
          return if segments.empty?

          last = segments.pop
          cursor = payload

          segments.each do |segment|
            existing = cursor[segment]
            cursor[segment] = {} unless existing.is_a?(Hash)
            cursor = cursor[segment]
          end

          cursor[last] = value
        end
      end
    end
  end
end
