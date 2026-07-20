#!/usr/bin/env ruby
# frozen_string_literal: true
# Delegate local production-mode boot to the backend repository.

require_relative "../../workspace"

module Workspace
  module Services
    class ProdLocal
      BACKEND_PURPOSE = "backend-api"

      def initialize(argv)
        @argv = argv.dup
      end

      def call
        return usage unless argv.empty?

        Workspace.section("Prod Local: Delegating to API Template")

        api_repo = backend_repo_path
        return 1 unless verify_backend_repo!(api_repo)

        script = File.join(api_repo, "bin", "prod-local")
        unless File.executable?(script)
          Workspace.fail_with_help(
            "API template local production script is missing.",
            details: "Expected executable: #{script}",
            fixes: [
              "Ensure repos/api-template is up to date and includes bin/prod-local.",
              "Run bin/bootstrap and retry.",
              "Run the repo-local command directly after syncing: #{File.join(api_repo, 'bin', 'prod-local')}"
            ]
          )
          return 1
        end

        Workspace.info("Delegating to #{script}")
        exec("bin/prod-local", chdir: api_repo)
      end

      private

      attr_reader :argv

      def usage
        puts "Usage: bin/workspace prod-local"
        1
      end

      def backend_repo_path
        repo = Workspace.repositories.find { |entry| entry["purpose"].to_s == BACKEND_PURPOSE }
        relative_path = repo && repo["path"].to_s
        relative_path = "repos/api-template" if relative_path.nil? || relative_path.empty?

        File.join(Workspace::ROOT, relative_path)
      end

      def verify_backend_repo!(api_repo)
        unless File.directory?(api_repo)
          Workspace.fail_with_help(
            "Backend repository path is missing.",
            details: "Expected directory: #{api_repo}",
            fixes: [
              "Ensure the backend repository is present and bootstrapped.",
              "Run bin/pull or repository setup to ensure repos are present.",
              "Verify repository path mapping for purpose '#{BACKEND_PURPOSE}' in config/project.yml."
            ]
          )
          return false
        end

        true
      end
    end
  end
end
