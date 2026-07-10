# frozen_string_literal: true

require "yaml"
require_relative "errors"
require_relative "schema"

module Workspace
  module ProjectManifest
    # Loads config/project.yml and delegates structural validation to Schema.
    # Raises InvalidManifest with file-path context for parse/validation failures.
    class Loader
      def initialize(root:)
        @root = root
        @schema_class = Workspace::ProjectManifest::Schema
      end

      def load
        return unless File.exist?(manifest_path)

        manifest = YAML.safe_load_file(
          manifest_path,
          permitted_classes: [],
          aliases: false
        ) || {}

        schema_class.new(manifest: manifest).validate!
        manifest
      rescue Psych::SyntaxError => e
        raise InvalidManifest,
              "#{manifest_path}: invalid YAML: #{e.message}"
      rescue Schema::ValidationError => e
        raise InvalidManifest,
              "#{manifest_path}: #{e.message}"
      end

      private

      attr_reader :root, :schema_class

      def manifest_path
        @manifest_path ||= File.join(root, "config", "project.yml")
      end
    end
  end
end