#!/usr/bin/env ruby
# frozen_string_literal: true
# Interactive guided installer for required local tools and auth setup.

require "fileutils"
require "yaml"
require "rbconfig"
require_relative "../../workspace"
require_relative "doctor_command"

module Workspace
  module Commands
    class SetupToolsCommand
      PREFERENCES_PATH = File.join(Workspace::ROOT, ".workspace", "setup_tools.yml")
      REQUIRED_TOOLS = [
        { id: "ruby", label: "Ruby", command: "ruby" },
        { id: "docker", label: "Docker", command: "docker" },
        { id: "doctl", label: "doctl", command: "doctl" },
        { id: "gh", label: "GitHub CLI", command: "gh" },
        { id: "terraform", label: "Terraform", command: "terraform" }
      ].freeze

      def initialize(stdin: $stdin, stdout: $stdout)
        @stdin = stdin
        @stdout = stdout
        @command_exists_cache = {}
        @preferences = {
          "install_missing" => {},
          "configure" => {}
        }
      end

      def call
        Workspace.section("Setup Tools: Guided Installer")
        load_preferences

        missing = print_tool_status
        if missing.empty?
          Workspace.ok("All required tools are installed.")
        else
          install_missing_tools(missing)
        end

        run_optional_configuration
        save_preferences
        print_final_status
      end

      private

      attr_reader :stdin, :stdout, :preferences

      def host_os
        @host_os ||= RbConfig::CONFIG["host_os"].to_s
      end

      def macos?
        host_os.include?("darwin")
      end

      # Loads persisted setup choices and optionally reuses them for this run.
      def load_preferences
        return unless File.exist?(preferences_path)

        parsed = YAML.safe_load(File.read(preferences_path), permitted_classes: [], aliases: false)
        return unless parsed.is_a?(Hash)

        if prompt_yes_no("Reuse saved setup preferences from previous run?", default: true)
          preferences["install_missing"].merge!(parsed.fetch("install_missing", {}))
          preferences["configure"].merge!(parsed.fetch("configure", {}))
          Workspace.info("Loaded saved setup preferences.")
        else
          Workspace.info("Starting with fresh interactive choices.")
        end
      rescue Psych::SyntaxError
        Workspace.warn("Ignoring invalid preferences yml file at #{preferences_path}.")
      end

      def save_preferences
        FileUtils.mkdir_p(File.dirname(preferences_path))
        File.write(preferences_path, preferences.to_yaml)
      rescue StandardError => e
        Workspace.warn("Could not save setup preferences: #{e.class}: #{e.message}")
      end

      def print_tool_status
        missing = []

        REQUIRED_TOOLS.each do |tool|
          if tool_installed?(tool)
            Workspace.ok("#{tool[:label]}: installed")
          else
            Workspace.warn("#{tool[:label]}: missing")
            missing << tool
          end
        end

        missing
      end

      def tool_installed?(tool)
        return ruby_ready? if tool[:id] == "ruby"

        command_available?(tool[:command])
      end

      def ruby_ready?
        command_available?("ruby") && Workspace.ruby_compatible?
      end

      def install_missing_tools(missing_tools)
        Workspace.section("Install Missing Tools", color: :magenta, divider_char: "-")

        missing_tools.each do |tool|
          install_default = preferences.dig("install_missing", tool[:id])
          should_install = prompt_yes_no(
            "Install #{tool[:label]} now?",
            default: install_default.nil? ? false : install_default
          )
          preferences["install_missing"][tool[:id]] = should_install
          next unless should_install

          install_tool(tool)
        end
      end

      def install_tool(tool)
        case tool[:id]
        when "ruby"
          install_ruby_with_mise
        when "docker"
          install_docker
        when "doctl"
          install_with_brew("doctl", "DigitalOcean CLI")
        when "gh"
          install_with_brew("gh", "GitHub CLI")
        when "terraform"
          install_terraform
        else
          Workspace.warn("No installer is configured for #{tool[:label]}.")
        end
      end

      def ensure_homebrew
        return true if command_available?("brew")

        unless macos?
          Workspace.fail_with_help(
            "Homebrew is missing and auto-install is only configured for macOS.",
            details: "Detected OS: #{host_os}",
            fixes: [
              "Install Homebrew manually for your OS if supported, then rerun bin/setup_tools.",
              "Or install required tools with your system package manager and rerun this script."
            ]
          )
          return false
        end

        Workspace.info("Installing Homebrew (required for guided installs on macOS)")
        ok = Workspace.run(
          "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"",
          allow_failure: true,
          summary: "Homebrew installation failed.",
          details: "Could not install Homebrew via official installer script.",
          fixes: [
            "Retry bin/setup_tools and approve installer prompts when requested.",
            "Check network access to raw.githubusercontent.com.",
            "Install Homebrew manually, then rerun this script."
          ]
        )

        refresh_command_availability("brew") if ok
        ok
      end

      def install_with_brew(formula, label)
        return unless ensure_homebrew

        Workspace.info("Installing #{label}")
        ok = Workspace.run(
          "brew install #{formula}",
          allow_failure: true,
          summary: "#{label} installation failed.",
          details: "brew install #{formula} did not complete successfully.",
          fixes: [
            "Run brew doctor and resolve reported issues.",
            "Retry the install with bin/setup_tools."
          ]
        )

        refresh_command_availability(formula) if ok
      end

      def install_terraform
        return unless ensure_homebrew

        Workspace.info("Installing Terraform")
        Workspace.run(
          "brew tap hashicorp/tap",
          allow_failure: true,
          summary: "Terraform tap setup failed.",
          details: "Could not add hashicorp/tap Homebrew repository.",
          fixes: [
            "Check network connectivity and Homebrew configuration.",
            "Retry bin/setup_tools."
          ]
        )

        ok = Workspace.run(
          "brew install hashicorp/tap/terraform",
          allow_failure: true,
          summary: "Terraform installation failed.",
          details: "brew install hashicorp/tap/terraform did not complete successfully.",
          fixes: [
            "Run brew doctor and retry.",
            "Verify no conflicting terraform binaries are blocking install."
          ]
        )

        refresh_command_availability("terraform") if ok
      end

      def install_docker
        return unless ensure_homebrew

        Workspace.info("Installing Docker Desktop")
        ok = Workspace.run(
          "brew install --cask docker-desktop",
          allow_failure: true,
          summary: "Docker Desktop installation failed.",
          details: "brew install --cask docker-desktop did not complete successfully.",
          fixes: [
            "Close existing Docker installers and retry.",
            "Run brew doctor and resolve cask issues."
          ]
        )

        refresh_command_availability("docker") if ok
      end

      def install_ruby_with_mise
        return unless ensure_homebrew

        required = Workspace.required_ruby_version
        Workspace.info("Installing mise")
        mise_ok = Workspace.run(
          "brew install mise",
          allow_failure: true,
          summary: "mise installation failed.",
          details: "brew install mise did not complete successfully.",
          fixes: [
            "Run brew doctor and resolve issues.",
            "Retry bin/setup_tools."
          ]
        )

        refresh_command_availability("mise") if mise_ok

        Workspace.info("Installing Ruby #{required} with mise")
        ruby_ok = Workspace.run(
          "mise install ruby@#{required}",
          allow_failure: true,
          summary: "Ruby installation with mise failed.",
          details: "Could not install ruby@#{required} via mise.",
          fixes: [
            "Ensure build dependencies are installed (Xcode CLT on macOS).",
            "Retry bin/setup_tools after resolving mise install errors."
          ]
        )

        Workspace.run(
          "mise use --global ruby@#{required}",
          allow_failure: true,
          summary: "Could not set global Ruby version with mise.",
          details: "mise use --global ruby@#{required} failed.",
          fixes: [
            "Check your shell profile for mise activation.",
            "Restart your shell and rerun bin/setup_tools."
          ]
        )

        refresh_command_availability("ruby") if ruby_ok
      end

      def run_optional_configuration
        Workspace.section("Optional Configuration", color: :magenta, divider_char: "-")

        configure_docker_daemon
        configure_github_auth
        configure_doctl_auth
      end

      def configure_docker_daemon
        return unless command_available?("docker")

        _out, running = Workspace.capture("docker info")
        return Workspace.ok("Docker daemon: running") if running

        default = preferences.dig("configure", "docker_start")
        should_start = prompt_yes_no(
          "Docker is installed but daemon is not running. Start Docker Desktop now?",
          default: default.nil? ? false : default
        )
        preferences["configure"]["docker_start"] = should_start
        return unless should_start

        Workspace.run(
          "open -a Docker",
          allow_failure: true,
          summary: "Could not start Docker Desktop.",
          details: "The command 'open -a Docker' failed.",
          fixes: [
            "Launch Docker Desktop manually from Applications.",
            "Retry this script after Docker is running."
          ]
        )

        wait_for_docker_daemon
      end

      def wait_for_docker_daemon
        30.times do
          _out, running = Workspace.capture("docker info")
          if running
            Workspace.ok("Docker daemon is now running")
            return
          end

          sleep 1
        end

        Workspace.warn("Docker daemon did not become ready yet. Continue once Docker finishes starting.")
      end

      def configure_github_auth
        return unless command_available?("gh")

        _out, ok = Workspace.capture("gh auth status")
        return Workspace.ok("GitHub CLI auth: configured") if ok

        default = preferences.dig("configure", "gh_auth")
        should_auth = prompt_yes_no("GitHub CLI is not authenticated. Run gh auth login now?", default: default.nil? ? false : default)
        preferences["configure"]["gh_auth"] = should_auth
        return unless should_auth

        Workspace.run(
          "gh auth login",
          allow_failure: true,
          summary: "GitHub CLI authentication failed.",
          details: "gh auth login did not complete successfully.",
          fixes: [
            "Retry gh auth login and complete prompts.",
            "If using SSO orgs, authorize token access after login."
          ]
        )
      end

      def configure_doctl_auth
        return unless command_available?("doctl")

        _out, ok = Workspace.capture("doctl auth list")
        return Workspace.ok("doctl auth: configured") if ok

        default = preferences.dig("configure", "doctl_auth")
        should_auth = prompt_yes_no("doctl is not authenticated. Run doctl auth init now?", default: default.nil? ? false : default)
        preferences["configure"]["doctl_auth"] = should_auth
        return unless should_auth

        Workspace.run(
          "doctl auth init",
          allow_failure: true,
          summary: "doctl authentication failed.",
          details: "doctl auth init did not complete successfully.",
          fixes: [
            "Retry doctl auth init and provide a valid token.",
            "Confirm token scope includes required DigitalOcean permissions."
          ]
        )
      end

      def print_final_status
        Workspace.section("Final Tool Status", color: :cyan, divider_char: "-")
        print_tool_status

        Workspace.info("Running environment diagnostics (bin/doctor equivalent)")
        doctor_result = Workspace::Commands::DoctorCommand.new.call
        return 0 if doctor_result.zero?

        Workspace.warn("Setup completed with remaining issues. Re-run bin/setup_tools to continue.")
        1
      end

      def prompt_yes_no(question, default: true)
        indicator = default ? "Y/n" : "y/N"
        stdout.print("#{question} [#{indicator}]: ")
        answer = stdin.gets&.strip.to_s.downcase

        return default if answer.empty?
        return true if %w[y yes].include?(answer)
        return false if %w[n no].include?(answer)

        default
      end

      def command_available?(command)
        return command_exists_cache[command] if command_exists_cache.key?(command)

        command_exists_cache[command] = Workspace.command_exists?(command)
      end

      def refresh_command_availability(command)
        command_exists_cache[command] = Workspace.command_exists?(command)
      end

      def command_exists_cache
        @command_exists_cache
      end

      def preferences_path
        PREFERENCES_PATH
      end
    end
  end
end

