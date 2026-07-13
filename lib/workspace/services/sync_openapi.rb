#!/usr/bin/env ruby
# frozen_string_literal: true
# Command object for synchronizing OpenAPI artifacts and optional type generation.

require "fileutils"
require "json"
require_relative "../../workspace"

module Workspace
  module Services
    class SyncOpenapi
      def call
        return 1 unless source_openapi_exists?

        sync_openapi_targets
        regenerate_web_types_if_configured
      end

      private

      def source_openapi_path
        File.join(api_repo_root, "docs", "openapi.yml")
      end

      def source_openapi_exists?
        return true if File.exist?(source_openapi_path)

        Workspace.fail_with_help(
          "OpenAPI source file is missing.",
          details: "Expected source file at #{source_openapi_path}, but it does not exist.",
          assumptions: [
            "The backend API repo owns the source OpenAPI document at docs/openapi.yml.",
            "Contract sync assumes that file is generated and committed before synchronization."
          ],
          fixes: [
            "Ensure the backend-api repository path in config/repos.yml is correct and available.",
            "Generate or export the API spec in your backend repo so docs/openapi.yml exists.",
            "Retry bin/sync-openapi after the source file is present."
          ]
        )
        false
      end

      def sync_openapi_targets
        openapi_targets.each do |target|
          FileUtils.mkdir_p(File.dirname(target))
          FileUtils.cp(source_openapi_path, target)
          Workspace.ok("synced OpenAPI to #{relative_path(target)}")
        end
      end

      def openapi_targets
        [
          File.join(Workspace::ROOT, "contracts", "openapi", "openapi.yml"),
          File.join(web_repo, "openapi", "openapi.yml")
        ]
      end

      def regenerate_web_types_if_configured
        return 0 unless File.exist?(web_package_json)

        package = JSON.parse(File.read(web_package_json))
        scripts = package.fetch("scripts", {})
        return skip_web_type_generation unless scripts.key?("generate:types")

        Workspace.warn("regenerating web types via npm run generate:types")
        ok = Workspace.run("npm run generate:types", chdir: web_repo, allow_failure: true)
        return 0 if ok

        Workspace.fail_with_help(
          "Web type generation failed after OpenAPI sync.",
          details: "The script npm run generate:types failed in #{relative_path(web_repo)}.",
          assumptions: [
            "The frontend web repo has a valid generate:types script and required tooling dependencies.",
            "The synced OpenAPI document is compatible with the configured type generator."
          ],
          fixes: [
            "Run npm run generate:types manually in #{relative_path(web_repo)} for full error details.",
            "Install missing web dependencies with npm install if needed.",
            "Fix generator or schema issues, then rerun bin/sync-openapi."
          ]
        )
        1
      end

      def skip_web_type_generation
        Workspace.warn("#{relative_path(web_repo)} has no generate:types script; skipping type generation")
        0
      end

      def web_repo
        @web_repo ||= repository_root_by_purpose("frontend-web-client", "repos/web-template")
      end

      def api_repo_root
        @api_repo_root ||= repository_root_by_purpose("backend-api", "repos/api-template")
      end

      def repository_root_by_purpose(purpose, fallback_relative_path)
        repo = Workspace.repositories.find { |entry| entry["purpose"].to_s == purpose }
        relative_path = repo && repo["path"].to_s
        relative_path = fallback_relative_path if relative_path.nil? || relative_path.empty?
        File.join(Workspace::ROOT, relative_path)
      end

      def web_package_json
        File.join(web_repo, "package.json")
      end

      def relative_path(path)
        path.sub("#{Workspace::ROOT}/", "")
      end
    end
  end
end
