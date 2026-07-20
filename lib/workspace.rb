#!/usr/bin/env ruby
# frozen_string_literal: true
# Shared helpers for workspace script configuration, command execution, and output.

require "open3"
require "yaml"
require "fileutils"
require "rubygems"
require "pastel"
require_relative "workspace/project_manifest/loader"
require_relative "workspace/context"
require_relative "workspace/services/docker/daemon_manager"

module Workspace
  ROOT = File.expand_path("..", __dir__)

  module_function

  def pastel
    @pastel ||= Pastel.new(enabled: $stdout.tty?)
  end

  def styled_label(label, color: :white, bold: true)
    text = "[#{label}]"
    text = pastel.decorate(text, color) if color
    bold ? pastel.bold(text) : text
  end

  def load_yaml(path, fallback, context: nil)
    root = context&.root || ROOT
    full_path = File.join(root, path)
    return fallback unless File.exist?(full_path)

    YAML.safe_load(File.read(full_path), permitted_classes: [], aliases: false) || fallback
  rescue Psych::SyntaxError => e
    abort_with_help(
      "Configuration file could not be parsed.",
      details: "Invalid YAML detected in #{path}. Parser error: #{e.message}",
      fixes: [
        "Open #{path} and validate indentation, colons, and list formatting.",
        "Run: ruby -ryaml -e 'YAML.safe_load(File.read(\"#{path}\"), permitted_classes: [], aliases: false)'",
        "Fix the syntax issue and run the original workspace command again."
      ]
    )
  end

  def ports(context: nil)
    services = if context
                 manifest = context.manifest
                 raw = manifest["services"]
                 raw.is_a?(Hash) ? raw : {}
               else
                 project_manifest_services
               end
    unless services.empty?
      return services.each_with_object({}) do |(name, config), acc|
        acc[name] = Integer(config["port"])
      rescue ArgumentError, TypeError
        acc[name] = config["port"]
      end
    end

    load_yaml("config/ports.yml", {}, context: context)
  end

  def repositories(context: nil)
    manifest_repositories = if context
                              normalize_repository_definitions(context.repositories)
                            else
                              project_manifest_repositories
                            end

    return manifest_repositories unless manifest_repositories.empty?

    root = context&.root || ROOT
    abort_with_help(
      "Repository configuration is missing from project manifest.",
      details: "Expected repository entries under config/project.yml -> repositories in #{root}.",
      assumptions: [
        "The project manifest is the single source of truth for repository metadata.",
        "Workspace commands require repository purpose/name/path entries to be present in the manifest."
      ],
      fixes: [
        "Add repository entries under config/project.yml: repositories.",
        "Ensure each repository defines at least purpose, name, and path.",
        "Re-run the workspace command after fixing manifest repositories."
      ]
    )
  end

  def repo_name(repo)
    repo["name"]
  end

  def repo_path(repo, context: nil)
    root = context&.root || ROOT
    File.join(root, repo.fetch("path"))
  end

  def existing_repositories(context: nil)
    repositories(context: context).select { |repo| Dir.exist?(repo_path(repo, context: context)) }
  end

  def command_exists?(command)
    system("command -v #{command} >/dev/null 2>&1")
  end

  def run(command, chdir: ROOT, allow_failure: false, summary: nil, details: nil, assumptions: [], fixes: [])
    puts pastel.cyan("$ #{command}")
    success = system(command, chdir: chdir)
    return true if success

    summary ||= "A required command failed and the workflow cannot continue."
    details ||= "Command: #{command} | Directory: #{chdir}"
    full_assumptions = default_command_assumptions(command, chdir) + assumptions
    full_fixes = default_command_fixes(command, chdir) + fixes

    if allow_failure
      fail_with_help(summary, details: details, assumptions: full_assumptions, fixes: full_fixes)
      return false
    end

    abort_with_help(summary, details: details, assumptions: full_assumptions, fixes: full_fixes)
  end

  def capture(command, chdir: ROOT)
    output, status = Open3.capture2e(command, chdir: chdir)
    [output, status.success?]
  end

  def docker_daemon_running?
    docker_daemon_manager.docker_daemon_running?
  end

  def ensure_docker_daemon_running(
    wait_attempts: 30,
    wait_interval: 1,
    launch_message: nil,
    launch_if_not_running: true,
    summary: "Could not start Docker Desktop.",
    details: "The command 'open -g -a Docker' failed.",
    fixes: []
  )
    docker_daemon_manager.ensure_docker_daemon_running(
      wait_attempts: wait_attempts,
      wait_interval: wait_interval,
      launch_message: launch_message,
      launch_if_not_running: launch_if_not_running,
      summary: summary,
      details: details,
      fixes: fixes
    )
  end

  def wait_for_docker_daemon(wait_attempts:, wait_interval:)
    docker_daemon_manager.wait_for_docker_daemon(
      wait_attempts: wait_attempts,
      wait_interval: wait_interval
    )
  end

  def docker_desktop_app_running?
    docker_daemon_manager.docker_desktop_app_running?
  end

  def docker_daemon_manager
    @docker_daemon_manager ||= Workspace::Services::Docker::DaemonManager.new(workspace: self)
  end

  def ok(message)
    puts "#{styled_label('OK', color: :green)} #{message}"
  end

  def info(message)
    puts "#{styled_label('INFO', color: :cyan)} #{message}"
  end

  def section(title, color: :cyan, width: 64, divider_char: "=")
    divider = divider_char * width
    decorated_divider = pastel.bold(pastel.decorate(divider, color))
    decorated_title = pastel.bold(pastel.decorate(title, color))

    puts
    puts decorated_divider
    puts decorated_title
    puts decorated_divider
    puts
  end

  def warn(message)
    puts "#{styled_label('WARN', color: :yellow)} #{message}"
  end

  def fail(message)
    puts "#{styled_label('FAIL', color: :red)} #{message}"
  end

  def fail_with_help(summary, details: nil, assumptions: [], fixes: [])
    puts "#{styled_label('FAIL', color: :red)} #{pastel.red(summary)}"
    puts "       #{pastel.dim(details)}" if details
    unless assumptions.empty?
      puts "       #{pastel.yellow('Assumptions:')}"
      assumptions.each_with_index do |assumption, index|
        puts format("       %s %s", pastel.yellow("#{index + 1}."), assumption)
      end
    end
    return if fixes.empty?

    puts "       #{pastel.green('How to fix:')}"
    fixes.each_with_index do |fix, index|
      puts format("       %s %s", pastel.green("#{index + 1}."), fix)
    end
  end

  def abort_with_help(summary, details: nil, assumptions: [], fixes: [])
    fail_with_help(summary, details: details, assumptions: assumptions, fixes: fixes)
    exit 1
  end

  def default_command_assumptions(command, chdir)
    [
      "The command '#{command}' is valid and available in PATH.",
      "The working directory exists and has the expected project files: #{chdir}.",
      "Your environment has required credentials and network access for this command."
    ]
  end

  def default_command_fixes(command, chdir)
    [
      "Run the same command manually in #{chdir} to see the full tool error output.",
      "Fix the reported issue (missing tool, auth, dependency, or config) and retry.",
      "Re-run the workspace command after '#{command}' succeeds."
    ]
  end

  def ruby_version
    Gem::Version.new(RUBY_VERSION)
  end

  def required_ruby_version
    candidates = [
      File.join(ROOT, ".ruby-version"),
      File.join(ROOT, "repos", "api-template", ".ruby-version")
    ]

    version_str = nil
    candidates.each do |path|
      next unless File.exist?(path)

      value = File.read(path).strip
      value = value.sub(/\Aruby[-\s]*/i, "").sub(/\Av/i, "")
      next if value.empty?

      version_str = value
      break
    end

    Gem::Version.new(version_str || "3.4.0")
  end

  def ruby_compatible?
    ruby_version >= required_ruby_version
  end

  def script_path(name, context: nil)
    if context
      context.script_path(name)
    else
      File.join(ROOT, "bin", name)
    end
  end

  def project_manifest
    return @project_manifest if defined?(@project_manifest)

    @project_manifest = project_manifest_loader.load
  end

  def project_manifest_loader
    @project_manifest_loader ||= Workspace::ProjectManifest::Loader.new(root: ROOT)
  end

  def project_manifest_repositories
    return [] unless project_manifest.is_a?(Hash)

    normalize_repository_definitions(project_manifest["repositories"])
  end

  def normalize_repository_definitions(raw_repositories)
    case raw_repositories
    when Array
      raw_repositories.select { |repo| repo.is_a?(Hash) }
    when Hash
      raw_repositories.values.select { |repo| repo.is_a?(Hash) }
    else
      []
    end
  end

  def project_manifest_services
    return {} unless project_manifest.is_a?(Hash)

    services = project_manifest["services"]
    services.is_a?(Hash) ? services : {}
  end
end
