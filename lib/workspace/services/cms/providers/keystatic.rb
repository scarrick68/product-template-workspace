# frozen_string_literal: true

require_relative "../package_json"
require_relative "../scaffold"

module Workspace
  module Services
    module Cms
      module Providers
        class Keystatic
          FRONTEND_PURPOSE = "frontend-web-client"

          DEPENDENCIES = {
            "@keystatic/core" => "^5.0.0"
          }.freeze

          DEV_DEPENDENCIES = {
            "tsx" => "^4.20.5"
          }.freeze

          SCRIPTS = {
            "content" => "vike dev",
            "content:check" => "tsx src/content/validate-content.ts"
          }.freeze

          FRONTEND_MAPPINGS = [
            { source: "keystatic/frontend/keystatic.config.ts", destination: "keystatic.config.ts", scope: :frontend },
            { source: "keystatic/frontend/src/content/validate-content.ts", destination: "src/content/validate-content.ts", scope: :frontend },
            { source: "keystatic/frontend/bin/content", destination: "bin/content", scope: :frontend },
            { source: "keystatic/frontend/bin/content-check", destination: "bin/content-check", scope: :frontend },
            { source: "keystatic/frontend/content/articles/hello-world/index.yaml", destination: "content/articles/hello-world/index.yaml", scope: :frontend },
            { source: "keystatic/frontend/content/articles/hello-world/body.mdoc", destination: "content/articles/hello-world/body.mdoc", scope: :frontend }
          ].freeze

          WORKSPACE_MAPPINGS = [
            { source: "keystatic/workspace/docs/content-authoring.md", destination: "docs/content-authoring.md", scope: :workspace }
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
        end
      end
    end
  end
end
