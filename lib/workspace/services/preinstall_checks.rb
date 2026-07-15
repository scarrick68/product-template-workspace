#!/usr/bin/env ruby
# frozen_string_literal: true
# Command object for validating workstation prerequisites before install workflows.

require_relative "../../workspace"

module Workspace
  module Services
    class PreinstallChecks
      def initialize
        @failed = false
      end

      def call
        Workspace.section("Preinstall: Environment Checks")
        check_ruby_compatibility
        check_github_cli_installation
        check_github_cli_authentication
        finalize
      end

      private

      attr_reader :failed

      def mark_failed
        @failed = true
      end

      def failed?
        failed
      end

      def check_ruby_compatibility
        required_ruby = Workspace.required_ruby_version
        installed_ruby = Workspace.ruby_version

        if Workspace.ruby_compatible?
          Workspace.ok("Ruby #{installed_ruby} is compatible (required >= #{required_ruby})")
          return
        end

        Workspace.fail_with_help(
          "Ruby version is not compatible with this workspace.",
          details: "Installed Ruby: #{installed_ruby} | Required minimum Ruby: #{required_ruby}",
          assumptions: [
            "Workspace scripts and template dependencies assume a Ruby version at or above the required minimum.",
            "Bundler and Rails tasks may fail if Ruby is older than expected."
          ],
          fixes: [
            "Install a compatible Ruby version (#{required_ruby} or newer) using mise, rbenv, or asdf.",
            "If using mise, run: mise install ruby@#{required_ruby} && mise use -g ruby@#{required_ruby}",
            "Restart your shell and verify with: ruby --version"
          ]
        )
        mark_failed
      end

      def check_github_cli_installation
        return if Workspace.command_exists?("gh")

        Workspace.fail_with_help(
          "GitHub CLI (gh) is required but not installed.",
          details: "The command 'gh' is not available in PATH.",
          assumptions: [
            "Workspace repository access and authentication checks are performed with GitHub CLI.",
            "Automation assumes 'gh auth status' can verify your login state."
          ],
          fixes: [
            "Install GitHub CLI from https://cli.github.com/ or with Homebrew: brew install gh.",
            "Restart your terminal so PATH updates are loaded.",
            "Verify installation with: gh --version"
          ]
        )
        mark_failed
      end

      def check_github_cli_authentication
        return unless Workspace.command_exists?("gh")

        gh_version, _ok = Workspace.capture("gh --version")
        Workspace.ok("GitHub CLI detected: #{gh_version.lines.first&.strip || 'gh installed'}")

        _auth_output, auth_ok = Workspace.capture("gh auth status")
        if auth_ok
          Workspace.ok("GitHub CLI authentication is valid")
          return
        end

        Workspace.fail_with_help(
          "GitHub CLI is installed but not authenticated.",
          details: "The command 'gh auth status' failed.",
          assumptions: [
            "Workspace automation assumes you can read required GitHub repositories.",
            "Clone and pull operations may fail if GitHub authentication is missing or expired."
          ],
          fixes: [
            "Run: gh auth login",
            "Select the correct GitHub host/account and complete login.",
            "Verify authentication with: gh auth status"
          ]
        )
        mark_failed
      end

      def finalize
        return success unless failed?

        Workspace.fail_with_help(
          "Pre-installation checks failed.",
          details: "One or more prerequisites are missing or misconfigured.",
          assumptions: [
            "Dependency installation and repository operations depend on a compatible Ruby and authenticated GitHub CLI.",
            "Proceeding without these prerequisites will likely produce cascading failures in later scripts."
          ],
          fixes: [
            "Resolve each failure block above in order.",
            "Re-run this script: bin/preinstall_checks",
            "Run bin/bootstrap only after preinstall_checks passes."
          ]
        )
        1
      end

      def success
        Workspace.ok("pre-installation checks passed")
        0
      end
    end
  end
end
