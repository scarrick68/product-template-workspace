#!/usr/bin/env ruby
# frozen_string_literal: true
# Shared helpers for workspace script configuration, command execution, and output.

require "open3"
require "yaml"
require "fileutils"
require "rubygems"
require "pastel"

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

  def load_yaml(path, fallback)
    full_path = File.join(ROOT, path)
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

  def ports
    load_yaml("config/ports.yml", {})
  end

  def repositories
    config = load_yaml("config/repos.yml", {})
    list = config["repositories"]
    return default_repositories unless list.is_a?(Array) && !list.empty?

    list
  end

  def default_repositories
    [
      { "name" => "api-template", "path" => "repos/api-template" },
      { "name" => "web-template", "path" => "repos/web-template" },
    ]
  end

  def repo_name(repo)
    repo["name"]
  end

  def repo_path(repo)
    File.join(ROOT, repo.fetch("path"))
  end

  def existing_repositories
    repositories.select { |repo| Dir.exist?(repo_path(repo)) }
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

  def ok(message)
    puts "#{styled_label('OK', color: :green)} #{message}"
  end

  def info(message)
    puts "#{styled_label('INFO', color: :cyan)} #{message}"
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

  def script_path(name)
    File.join(ROOT, "bin", name)
  end
end
