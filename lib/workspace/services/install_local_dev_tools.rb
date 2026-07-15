#!/usr/bin/env ruby
# frozen_string_literal: true
# Interactive guided installer for required local tools and auth setup.

require "fileutils"
require "yaml"
require "rbconfig"
require "tty-prompt"
require_relative "../../workspace"
require_relative "doctor"
require_relative "local_env_setup/config/service_auth_config"
require_relative "local_env_setup/config/service_config"
require_relative "local_env_setup/installers/install_docker"
require_relative "local_env_setup/installers/install_doctl"
require_relative "local_env_setup/installers/install_gh"
require_relative "local_env_setup/installers/install_ruby"
require_relative "local_env_setup/installers/install_terraform"

module Workspace
  module Services
    class InstallLocalDevTools
      PREFERENCES_PATH = File.join(Workspace::ROOT, ".workspace", "install_local_dev_tools.yml")
      REQUIRED_TOOLS = LocalEnvSetup::Config::ServiceConfig.required_tools
      SERVICE_AUTH_CONFIGS = LocalEnvSetup::Config::ServiceAuthConfig.all

      def initialize(stdin: $stdin, stdout: $stdout)
        @stdin = stdin
        @stdout = stdout
        @prompt = nil
        @command_exists_cache = {}
        @preferences = {
          "install_missing" => {},
          "configure" => {}
        }
      end

      def call
        Workspace.section("Setup Tools: Guided Installer")
        preferences_created = ensure_preferences_file_exists
        load_preferences(skip_prompt: preferences_created)

        missing = print_tool_status
        if missing.empty?
          Workspace.ok("All required tools are installed.")
        else
          return 1 unless install_missing_tools(missing)
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
      def load_preferences(skip_prompt: false)
        return unless File.exist?(preferences_path)

        parsed = YAML.safe_load(File.read(preferences_path), permitted_classes: [], aliases: false)
        return unless parsed.is_a?(Hash)

        install_missing = parsed.fetch("install_missing", {})
        configure = parsed.fetch("configure", {})
        return unless saved_preferences_present?(install_missing, configure)

        if skip_prompt
          preferences["install_missing"].merge!(install_missing)
          preferences["configure"].merge!(configure)
          return
        end

        if prompt_yes_no("Reuse saved setup preferences from previous run?", default: true)
          preferences["install_missing"].merge!(install_missing)
          preferences["configure"].merge!(configure)
          Workspace.info("Loaded saved setup preferences.")
        else
          Workspace.info("Starting with fresh interactive choices.")
        end
      rescue Psych::SyntaxError
        Workspace.warn("Ignoring invalid preferences yml file at #{preferences_path}.")
      end

      def saved_preferences_present?(install_missing, configure)
        install_hash = install_missing.is_a?(Hash) ? install_missing : {}
        configure_hash = configure.is_a?(Hash) ? configure : {}

        !install_hash.empty? || !configure_hash.empty?
      end

      def save_preferences
        FileUtils.mkdir_p(File.dirname(preferences_path))
        File.write(preferences_path, preferences.to_yaml)
      rescue StandardError => e
        Workspace.warn("Could not save setup preferences: #{e.class}: #{e.message}")
      end

      def ensure_preferences_file_exists
        return false if File.exist?(preferences_path)

        FileUtils.mkdir_p(File.dirname(preferences_path))
        File.write(preferences_path, default_preferences.to_yaml)
        true
      rescue StandardError => e
        Workspace.warn("Could not initialize setup preferences file: #{e.class}: #{e.message}")
        false
      end

      def print_tool_status
        missing = []

        REQUIRED_TOOLS.each do |tool|
          if tool_installed?(tool)
            Workspace.ok("#{tool.label}: installed")
          else
            Workspace.warn("#{tool.label}: missing")
            missing << tool
          end
        end

        missing
      end

      def tool_installed?(tool)
        return ruby_ready? if tool.ruby?

        command_available?(tool.command)
      end

      def ruby_ready?
        command_available?("ruby") && Workspace.ruby_compatible?
      end

      def install_missing_tools(missing_tools)
        Workspace.section("Install Missing Tools", color: :magenta, divider_char: "-")

        missing_tools.each do |tool|
          should_install = prompt_yes_no(
            "Install #{tool.label} now?",
            default: false,
            require_input: true
          )
          if should_install == :no_input
            Workspace.fail_with_help(
              "Interactive confirmation is required to install missing tools.",
              details: "No input was available to answer install prompt for #{tool.label}.",
              assumptions: [
                "The current execution context does not provide stdin input for prompts.",
                "Required tool installs should not be silently skipped when confirmations cannot be answered."
              ],
              fixes: [
                "Run bin/install_local_dev_tools directly in an interactive terminal session.",
                "When prompted, answer yes to install missing required tools such as Terraform.",
                "Re-run bin/install_local_dev_tools until final status shows all required tools installed."
              ]
            )
            return false
          end

          preferences["install_missing"][tool.id] = should_install
          next unless should_install

          install_tool(tool)
        end

        true
      end

      def install_tool(tool)
        return Workspace.warn("No installer is configured for #{tool.label}.") unless tool.installable?
        return unless ensure_homebrew

        tool.installer_class.new.call
        refresh_command_availability("mise") if tool.ruby?
        refresh_command_availability(tool.command)
      end

      def ensure_homebrew
        return true if command_available?("brew")

        install_default = preferences.dig("install_missing", "homebrew")
        should_install = prompt_yes_no(
          "Homebrew is missing. Install Homebrew now?",
          default: install_default.nil? ? false : install_default
        )
        preferences["install_missing"]["homebrew"] = should_install

        unless should_install
          Workspace.warn("Skipping Homebrew installation. Homebrew-based tool installs will be skipped.")
          return false
        end

        Workspace.info("Installing Homebrew")
        ok = Workspace.run(
          "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"",
          allow_failure: true,
          summary: "Homebrew installation failed.",
          details: "Could not install Homebrew via official installer script on #{host_os}.",
          fixes: [
            "Retry bin/install_local_dev_tools and approve installer prompts when requested.",
            "Check network access to raw.githubusercontent.com.",
            "Install Homebrew manually, then rerun this script."
          ]
        )

        refresh_command_availability("brew") if ok
        ok
      end

      def run_optional_configuration
        Workspace.section("Optional Configuration", color: :magenta, divider_char: "-")

        configure_docker_daemon
        SERVICE_AUTH_CONFIGS.each { |config| configure_service_auth(config) }
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

      def configure_service_auth(config)
        return unless command_available?(config.command)

        _out, ok = Workspace.capture(config.status_command)
        return Workspace.ok(config.success_message) if ok

        default = preferences.dig("configure", config.preference_key)
        should_auth = prompt_yes_no(config.prompt, default: default.nil? ? false : default)
        preferences["configure"][config.preference_key] = should_auth
        return unless should_auth

        Workspace.run(
          config.auth_command,
          allow_failure: true,
          summary: config.failure_summary,
          details: config.failure_details,
          fixes: config.failure_fixes
        )
      end

      def print_final_status
        Workspace.section("Final Tool Status", color: :cyan, divider_char: "-")
        missing = print_tool_status

        unless missing.empty?
          Workspace.fail_with_help(
            "Required tools are still missing after setup.",
            details: "Missing: #{missing.map(&:label).join(', ')}",
            assumptions: [
              "Workspace setup and infrastructure workflows require all tools listed above.",
              "Continuing without required tools will cause follow-on failures in later commands."
            ],
            fixes: [
              "Re-run: bin/install_local_dev_tools and choose yes for each missing required tool you want installed automatically.",
              "Or install missing tools manually, then re-run bin/install_local_dev_tools to verify.",
              "After install_local_dev_tools passes, continue with bin/preinstall_checks and bin/doctor."
            ]
          )
          return 1
        end

        Workspace.info("Running environment diagnostics (bin/doctor equivalent)")
        doctor_result = Workspace::Services::Doctor.new.call
        return 0 if doctor_result.zero?

        Workspace.warn("Setup completed with remaining issues. Re-run bin/install_local_dev_tools to continue.")
        1
      end

      def prompt_yes_no(question, default: true, require_input: false)
        stream = prompt_input_stream
        return :no_input if require_input && stream.respond_to?(:eof?) && stream.eof?

        tty_prompt.yes?(question, default: default)
      rescue TTY::Reader::InputInterrupt, TTY::Reader::EOFError
        return :no_input if require_input

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

      def default_preferences
        {
          "install_missing" => {},
          "configure" => {}
        }
      end

      def prompt_input_stream
        return stdin unless stdin.equal?($stdin)
        return stdin if stdin.tty?

        @prompt_input_stream ||= File.open("/dev/tty", "r")
      rescue StandardError
        stdin
      end

      def tty_prompt
        return @prompt if @prompt

        @prompt = TTY::Prompt.new(input: prompt_input_stream, output: stdout)
      end
    end
  end
end

