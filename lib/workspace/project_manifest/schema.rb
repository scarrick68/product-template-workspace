# frozen_string_literal: true

module Workspace
  module ProjectManifest
    # Validates the project manifest contract and raises ValidationError with
    # precise field-level paths when the manifest shape or values are invalid.
    class Schema
      class ValidationError < ArgumentError; end

      REQUIRED_TOP_LEVEL_KEYS = %w[
        project
        repositories
        services
        environments
      ].freeze

      attr_reader :manifest

      def initialize(manifest:)
        @manifest = manifest
      end

      def valid?
        require_object!(
          manifest,
          path: "config/project.yml",
          example: "project:, repositories:, services:, environments:"
        )

        missing_keys = REQUIRED_TOP_LEVEL_KEYS.reject { |key| manifest.key?(key) }

        unless missing_keys.empty?
          raise ValidationError,
                "config/project.yml is missing required sections: " \
                "#{missing_keys.join(', ')}"
        end

        # validate the sections of the manifest
        validate_project!(manifest.fetch("project"))
        validate_repositories!(manifest.fetch("repositories"))
        validate_services!(manifest.fetch("services"))
        validate_environments!(manifest.fetch("environments"))

        true
      end

      def validate!
        raise ValidationError, "config/project.yml is invalid" unless valid?
        manifest
      end

      private

      def validate_project!(project)
        require_object!(
          project,
          path: "config/project.yml: project",
          example: "project: { name: ..., slug: ..., default_environment: ... }"
        )

        require_strings!(
          project,
          %w[name slug default_environment],
          path: "config/project.yml: project"
        )
      end

      def validate_repositories!(repositories)
        require_object!(
          repositories,
          path: "config/project.yml: repositories",
          example: "repositories: { api: { name: ..., path: ... } }"
        )

        repositories.each do |key, repository|
          path = "config/project.yml: repositories.#{key}"

          require_object!(
            repository,
            path: path,
            example: "#{key}: { purpose: ..., name: ..., path: ... }"
          )

          require_strings!(
            repository,
            %w[purpose name path],
            path: path
          )
        end
      end

      def validate_services!(services)
        require_object!(
          services,
          path: "config/project.yml: services",
          example: "services: { api: { repository: api, port: 5001 } }"
        )

        services.each do |name, config|
          path = "config/project.yml: services.#{name}"

          require_object!(
            config,
            path: path,
            example: "#{name}: { port: 5001 }"
          )

          port = config["port"]

          unless integer_like?(port)
            raise ValidationError,
                  "#{path}.port must be an integer; found #{describe(port)}"
          end

          next unless config.key?("repository")

          repository = config["repository"].to_s.strip

          if repository.empty?
            raise ValidationError,
                  "#{path}.repository must be a non-empty repository key"
          end
        end
      end

      def validate_environments!(environments)
        require_object!(
          environments,
          path: "config/project.yml: environments",
          example: "environments: { production: { infrastructure: ... } }"
        )

        if environments.empty?
          raise ValidationError,
                "config/project.yml: environments must define at least one environment"
        end

        environments.each do |name, config|
          path = "config/project.yml: environments.#{name}"

          require_object!(
            config,
            path: path,
            example: "#{name}: { infrastructure: ... }"
          )

          require_object!(
            config["infrastructure"],
            path: "#{path}.infrastructure",
            example: "infrastructure: { provider: digitalocean, region: nyc3 }"
          )
        end
      end

      def require_object!(value, path:, example:)
        return if value.is_a?(Hash)

        raise ValidationError,
              "#{path} must contain named YAML fields; " \
              "found #{describe(value)}. Expected something like: #{example}"
      end

      def require_strings!(object, keys, path:)
        keys.each do |key|
          value = object[key]

          unless value.is_a?(String) && !value.strip.empty?
            raise ValidationError,
                  "#{path}.#{key} must be a non-empty string; " \
                  "found #{describe(value)}"
          end
        end
      end

      def integer_like?(value)
        Integer(value, exception: false) != nil
      end

      def describe(value)
        case value
        when nil
          "nothing"
        when Hash
          "an object"
        when Array
          "a list"
        when String
          value.empty? ? "an empty string" : value.inspect
        else
          "#{value.inspect} (#{value.class})"
        end
      end
    end
  end
end