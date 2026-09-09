#!/usr/bin/env ruby
# frozen_string_literal: true
# Command object for synchronizing OpenAPI artifacts and optional type generation.

require "fileutils"
require "json"
require_relative "../../workspace"

module Workspace
  module Services
    class SyncOpenapi
      TYPE_GENERATION_SCRIPTS = ["gen:api", "api:generate"].freeze

      def call
        return 1 unless source_openapi_exists?

        sync_openapi_targets
        regenerate_types_if_configured
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
        targets = [
          File.join(Workspace::ROOT, "contracts", "openapi", "openapi.yml")
        ]

        if repository_present?(web_repo)
          targets << File.join(web_repo, "openapi", "openapi.yml")
        else
          Workspace.warn("web repo not present at #{relative_path(web_repo)}; skipping OpenAPI copy")
        end

        if repository_present?(mobile_repo)
          targets << File.join(mobile_repo, "openapi", "openapi.yml")
        else
          Workspace.warn("mobile repo not present at #{relative_path(mobile_repo)}; skipping OpenAPI copy")
        end

        targets
      end

      def regenerate_types_if_configured
        if repository_present?(web_repo)
          return 1 unless regenerate_repository_types(
            repo_root: web_repo,
            repo_label: "web"
          )
        else
          Workspace.warn("web repo not present at #{relative_path(web_repo)}; skipping type generation")
        end

        if repository_present?(mobile_repo)
          return 1 unless regenerate_repository_types(
            repo_root: mobile_repo,
            repo_label: "mobile"
          )
        else
          Workspace.warn("mobile repo not present at #{relative_path(mobile_repo)}; skipping type generation")
        end

        0
      end

      def regenerate_repository_types(repo_root:, repo_label:)
        package_json = File.join(repo_root, "package.json")
        return true unless File.exist?(package_json)

        package = JSON.parse(File.read(package_json))
        scripts = package.fetch("scripts", {})
        script = type_generation_script_for(scripts)
        return skip_type_generation(repo_root) if script.nil?

        command = "npm run #{script}"
        Workspace.info("regenerating #{repo_label} types via #{command}")
        ok = Workspace.run(command, chdir: repo_root, allow_failure: true)
        return true if ok

        Workspace.fail_with_help(
          "#{repo_label.capitalize} type generation failed after OpenAPI sync.",
          details: "The script #{command} failed in #{relative_path(repo_root)}.",
          assumptions: [
            "The #{repo_label} repo has a valid OpenAPI type generation script and required tooling dependencies.",
            "The synced OpenAPI document is compatible with the configured type generator."
          ],
          fixes: [
            "Run #{command} manually in #{relative_path(repo_root)} for full error details.",
            "Install missing dependencies with npm install if needed.",
            "Fix generator or schema issues, then rerun bin/sync-openapi."
          ]
        )
        false
      end

      def skip_type_generation(repo_root)
        Workspace.warn(
          "#{relative_path(repo_root)} has no #{TYPE_GENERATION_SCRIPTS.join(' or ')} script; skipping type generation"
        )
        true
      end

      def type_generation_script_for(scripts)
        TYPE_GENERATION_SCRIPTS.find { |script| scripts.key?(script) }
      end

      def web_repo
        @web_repo ||= repository_root_by_purpose("frontend-web-client", "repos/web-template")
      end

      def api_repo_root
        @api_repo_root ||= repository_root_by_purpose("backend-api", "repos/api-template")
      end

      def mobile_repo
        @mobile_repo ||= repository_root_by_purpose("frontend-mobile-client", "repos/mobile-app-template")
      end

      def repository_root_by_purpose(purpose, fallback_relative_path)
        repo = Workspace.repositories.find { |entry| entry["purpose"].to_s == purpose }
        relative_path = repo && repo["path"].to_s
        relative_path = fallback_relative_path if relative_path.nil? || relative_path.empty?
        File.join(Workspace::ROOT, relative_path)
      end

      def relative_path(path)
        path.sub("#{Workspace::ROOT}/", "")
      end

      def repository_present?(repo_root)
        File.directory?(repo_root)
      end
    end
  end
end
