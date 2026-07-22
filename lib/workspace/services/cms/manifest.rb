# frozen_string_literal: true

require "yaml"

module Workspace
  module Services
    module Cms
      # Reads and writes the CMS feature state inside config/project.yml.
      class Manifest
        def initialize(context:)
          @context = context
          @path = context.path("config", "project.yml")
        end

        def enabled?
          cms_config["enabled"] == true
        end

        def provider
          cms_config["provider"].to_s.strip
        end

        def enabled_with?(provider)
          enabled? && self.provider == provider.to_s.strip
        end

        def enable!(provider:, authoring:, publishing:)
          manifest = load_manifest
          features = manifest["features"]
          features = {} unless features.is_a?(Hash)

          features["cms"] = {
            "enabled" => true,
            "provider" => provider,
            "authoring" => authoring,
            "publishing" => publishing
          }
          manifest["features"] = features

          File.write(path, YAML.dump(manifest))
        end

        private

        attr_reader :path

        def cms_config
          config = load_manifest.dig("features", "cms")
          config.is_a?(Hash) ? config : {}
        end

        def load_manifest
          YAML.safe_load_file(path, permitted_classes: [], aliases: false) || {}
        end
      end
    end
  end
end
