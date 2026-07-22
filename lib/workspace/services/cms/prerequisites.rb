# frozen_string_literal: true

require "json"

require_relative "install_error"
require_relative "package_json"
require_relative "providers/keystatic"

module Workspace
  module Services
    module Cms
      class Prerequisites
        FRONTEND_PURPOSE = "frontend-web-client"

        def initialize(context:)
          @context = context
        end

        def validate!
          frontend_root = resolve_frontend_root
          package_path = File.join(frontend_root, "package.json")

          unless File.exist?(package_path)
            raise InstallError.new(
              "CMS install prerequisites failed.",
              details: "Missing frontend package.json at #{package_path}.",
              fixes: [
                "Ensure the frontend template repository is present and initialized at #{frontend_root}.",
                "Restore package.json in the frontend repository before running CMS install.",
                "Re-run the CMS install command after the frontend repository is healthy."
              ]
            )
          end

          package = PackageJson.new(path: package_path)
                             .parse!
                             .validate_sections!("dependencies", "devDependencies", "scripts")

          existing = package.conflicting_keys(requirements: provider_requirements)
          return true if existing.empty?

          raise InstallError.new(
            "CMS install prerequisites failed.",
            details: "Refusing CMS install because package.json already defines: #{existing.join(', ')} (#{package_path}).",
            fixes: [
              "Remove the conflicting keys from package.json before running CMS install.",
              "Keep installer-owned CMS keys reserved for workspace automation."
            ]
          )
        end

        private

        attr_reader :context

        def provider_requirements
          {
            "dependencies" => Providers::Keystatic::DEPENDENCIES,
            "devDependencies" => Providers::Keystatic::DEV_DEPENDENCIES,
            "scripts" => Providers::Keystatic::SCRIPTS
          }
        end

        def resolve_frontend_root
          Workspace.repo_root_for_purpose!(FRONTEND_PURPOSE, context: context)
        rescue ArgumentError => e
          raise InstallError.new(
            "CMS install prerequisites failed.",
            details: e.message,
            fixes: [
              "Ensure config/project.yml includes the frontend repository definition with purpose '#{FRONTEND_PURPOSE}'.",
              "Re-run the CMS install command after repository metadata is corrected."
            ]
          )
        end
      end
    end
  end
end
