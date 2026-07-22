# frozen_string_literal: true

require "json"

require_relative "../install_error"
require_relative "../package_json"
require_relative "../scaffold"

module Workspace
  module Services
    module Cms
      module Providers
        class Keystatic
          FRONTEND_PURPOSE = "frontend-web-client"

          DEPENDENCIES = {
            "@keystatic/core" => "^0.6.0"
          }.freeze

          DEV_DEPENDENCIES = {
            "concurrently" => "^9.2.1",
            "tsx" => "^4.20.5"
          }.freeze

          SCRIPTS = {
            "content" => "npm run --workspace=@workspace/keystatic-admin dev",
            "content:build" => "npm run --workspace=@workspace/keystatic-admin build",
            "dev:content" => "concurrently --kill-others-on-fail --names vike,content \"npm run dev\" \"npm run content\"",
            "content:check" => "tsx src/content/validate-content.ts"
          }.freeze

          FRONTEND_MAPPINGS = [
            { source: "keystatic/frontend/keystatic.config.ts", destination: "keystatic.config.ts", scope: :frontend },
            { source: "keystatic/frontend/src/content/validate-content.ts", destination: "src/content/validate-content.ts", scope: :frontend },
            { source: "keystatic/frontend/bin/content", destination: "bin/content", scope: :frontend },
            { source: "keystatic/frontend/bin/content-check", destination: "bin/content-check", scope: :frontend },
            { source: "keystatic/frontend/packages/keystatic-admin/package.json", destination: "packages/keystatic-admin/package.json", scope: :frontend },
            { source: "keystatic/frontend/packages/keystatic-admin/astro.config.mjs", destination: "packages/keystatic-admin/astro.config.mjs", scope: :frontend },
            { source: "keystatic/frontend/packages/keystatic-admin/keystatic.config.ts", destination: "packages/keystatic-admin/keystatic.config.ts", scope: :frontend },
            { source: "keystatic/frontend/packages/keystatic-admin/src/pages/index.astro", destination: "packages/keystatic-admin/src/pages/index.astro", scope: :frontend },
            { source: "keystatic/frontend/content/articles/hello-world/index.yaml", destination: "content/articles/hello-world/index.yaml", scope: :frontend },
            { source: "keystatic/frontend/content/articles/hello-world/body.mdoc", destination: "content/articles/hello-world/body.mdoc", scope: :frontend }
          ].freeze

          WORKSPACE_MAPPINGS = [
            { source: "keystatic/workspace/docs/content-authoring.md", destination: "docs/content-authoring.md", scope: :workspace },
            { source: "keystatic/workspace/docs/local-cms-subsystem.md", destination: "docs/local-cms-subsystem.md", scope: :workspace }
          ].freeze

          FRONTEND_EXECUTABLES = %w[bin/content bin/content-check].freeze

          def self.dependencies
            DEPENDENCIES
          end

          def self.dev_dependencies
            DEV_DEPENDENCIES
          end

          def self.scripts
            SCRIPTS
          end

          def initialize(context:)
            @context = context
          end

          def install
            frontend_root = Workspace.repo_root_for_purpose!(FRONTEND_PURPOSE, context: context)
            package_path = File.join(frontend_root, "package.json")

            package = PackageJson.new(path: package_path).parse!
            package.apply!(requirements: {
                             "dependencies" => self.class.dependencies,
                             "devDependencies" => self.class.dev_dependencies,
                             "scripts" => self.class.scripts
                           })
            package.write!
            ensure_workspace_settings!(package_path)

            scaffold.copy_templates(
              frontend_root: frontend_root,
              mappings: FRONTEND_MAPPINGS + WORKSPACE_MAPPINGS,
              executable_destinations: FRONTEND_EXECUTABLES
            )
          end

          private

          attr_reader :context

          def scaffold
            @scaffold ||= Scaffold.new(context: context)
          end

          def ensure_workspace_settings!(package_path)
            data = JSON.parse(File.read(package_path))

            data["private"] = true if data["private"].nil?

            workspaces = data["workspaces"]
            if workspaces.nil?
              data["workspaces"] = ["packages/*"]
            elsif workspaces.is_a?(Array)
              data["workspaces"] = (workspaces + ["packages/*"]).uniq
            else
              raise InstallError.new(
                "CMS install prerequisites failed.",
                details: "Expected workspaces to be an array in #{package_path}.",
                fixes: [
                  "Restore workspaces to an array in package.json.",
                  "Re-run the CMS install command after fixing package.json structure."
                ]
              )
            end

            File.write(package_path, JSON.pretty_generate(data) + "\n")
          end
        end
      end
    end
  end
end
