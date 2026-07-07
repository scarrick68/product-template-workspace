#!/usr/bin/env ruby
# frozen_string_literal: true
# Command object for workspace environment diagnostics.

require_relative "../../workspace"
require_relative "auth/github_auth_command"

module Workspace
  module Commands
    class DoctorCommand
      REQUIRED_COMMANDS = {
        "Ruby" => ["ruby", "ruby --version"],
        "Node" => ["node", "node --version"],
        "npm" => ["npm", "npm --version"],
        "Docker" => ["docker", "docker --version"],
        "GitHub CLI" => ["gh", "gh --version"],
        "doctl" => ["doctl", "doctl version"],
        "Terraform" => ["terraform", "terraform version"]
      }.freeze

      OPTIONAL_COMMANDS = {
        "mise" => ["mise", "mise --version"],
        "Postgres client" => ["psql", "psql --version"]
      }.freeze

      def call
        Workspace.section("Doctor: Environment Diagnostics")
        check_required_tools
        check_optional_tools
        check_docker_daemon
        check_github_auth
        check_expected_ports

        failed? ? 1 : 0
      end

      private

      attr_reader :checks_failed

      def initialize
        @checks_failed = false
      end

      def mark_failed
        @checks_failed = true
      end

      def failed?
        checks_failed
      end

      def check_required_tools
        REQUIRED_COMMANDS.each do |label, (command, version_command)|
          if Workspace.command_exists?(command)
            output, _ok = Workspace.capture(version_command)
            Workspace.ok("#{label}: #{output.lines.first&.strip || 'installed'}")
            next
          end

          Workspace.fail_with_help(
            "Required tool missing: #{label}.",
            details: "The command '#{command}' is not available in your PATH.",
            assumptions: [
              "Workspace scripts assume '#{command}' is available for related setup or runtime tasks.",
              "Missing core tools commonly cause follow-on errors in bootstrap and dev commands."
            ],
            fixes: [
              "Install #{label} using your preferred package manager or official installer.",
              "Restart your terminal so PATH changes are loaded.",
              "Verify with: #{command} --version"
            ]
          )
          mark_failed
        end
      end

      def check_optional_tools
        OPTIONAL_COMMANDS.each do |label, (command, version_command)|
          if Workspace.command_exists?(command)
            output, _ok = Workspace.capture(version_command)
            Workspace.ok("#{label}: #{output.lines.first&.strip || 'installed'}")
            next
          end

          case command
          when "mise"
            Workspace.warn("mise is not installed. Any Ruby 4+ installation is acceptable for workspace scripts.")
          when "psql"
            Workspace.warn("Postgres client (psql) is not installed or not running. This is optional because the API project may use a Docker-managed Postgres container internally. But you must do one of the following: install psql, run Postgres in Docker, or configure your API project to use a different database.")
          else
            Workspace.warn("Optional tool missing: #{label} (#{command})")
          end
        end
      end

      def check_docker_daemon
        return unless Workspace.command_exists?("docker")

        _docker_out, docker_ok = Workspace.capture("docker info")
        if docker_ok
          Workspace.ok("Docker daemon: running")
          return
        end

        Workspace.fail_with_help(
          "Docker is installed but the daemon is not running.",
          details: "The command 'docker info' failed, which usually means Docker Desktop/daemon is stopped.",
          assumptions: [
            "Container-backed dependencies may be required by template setup and local development.",
            "Scripts that need services like Postgres/Redis via Docker assume the daemon is running."
          ],
          fixes: [
            "Start Docker Desktop (or your Docker daemon service).",
            "Wait until Docker reports it is fully started.",
            "Re-run: docker info"
          ]
        )
        mark_failed
      end

      def check_github_auth
        result = Workspace::Commands::Auth::GithubAuthCommand.new.call
        mark_failed unless result.zero?
      end

      def check_expected_ports
        Workspace.ports.each do |name, port|
          next unless port

          _out, occupied = Workspace.capture("lsof -iTCP:#{port} -sTCP:LISTEN -n -P")
          if occupied
            Workspace.warn("Port #{port} (#{name}) is occupied")
          else
            Workspace.ok("Port #{port} (#{name}) is available")
          end
        end
      end
    end
  end
end
