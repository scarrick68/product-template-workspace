#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "yaml"

require_relative "../workspace"
require_relative "./project_paths"
require_relative "./local_infrastructure/backend_ci"
require_relative "./validation/check"
require_relative "./validation/check_runner"
require_relative "./validation/content_reachability"
require_relative "./validation/report"

module ProductTemplates
  class Validator
    attr_reader :product_slug, :workspace_root, :repositories, :stdin, :stdout

    def initialize(product_slug, workspace_root: Workspace::ROOT, repositories: Workspace.repositories, stdin: $stdin, stdout: $stdout)
      @product_slug = product_slug.to_s.strip
      @workspace_root = workspace_root
      @repositories = repositories
      @stdin = stdin
      @stdout = stdout
    end

    def call
      validate_product_slug!
      return 1 unless validate_cms_local_dev_wiring
      return 1 unless backend_ci.prepare

      results = check_runner.run(check_definitions)
      report.print(results)

      results.all?(&:passed?) ? 0 : 1
    end

    private

    def check_definitions
      checks = [
        check("API CI", "bin/ci", paths.backend_current_path, paths.backend_current_relative_path),
        check("WEB lint", "npm run lint", paths.frontend_current_path, paths.frontend_current_relative_path),
        check("WEB tests", "npm run test", paths.frontend_current_path, paths.frontend_current_relative_path),
        check("WEB build", "npm run build", paths.frontend_current_path, paths.frontend_current_relative_path),
        check("Workspace status", "bin/status", workspace_root, ".")
      ]

      if cms_enabled?
        checks.insert(4, check("WEB content check", "npm run content:check", paths.frontend_current_path, paths.frontend_current_relative_path))
        checks.insert(5, check(
          "WEB vike dev reachability",
          nil,
          paths.frontend_current_path,
          paths.frontend_current_relative_path,
          callable: -> { cms_reachability_check(:vike) }
        ))
        checks.insert(6, check(
          "WEB keystatic admin reachability",
          nil,
          paths.frontend_current_path,
          paths.frontend_current_relative_path,
          callable: -> { cms_reachability_check(:keystatic) }
        ))
      end

      checks
    end

    def check(name, command, directory, directory_label, callable: nil)
      Validation::Check.new(
        name: name,
        command: command,
        directory: directory,
        directory_label: directory_label,
        callable: callable
      )
    end

    def validate_product_slug!
      return if product_slug.match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/)

      Workspace.abort_with_help(
        "Invalid product name.",
        details: "Expected kebab-case (example: my-super-app), received '#{product_slug}'.",
        fixes: [
          "Use lowercase letters, numbers, and single dashes.",
          "Try: bin/validate_product my-super-app"
        ]
      )
    end

    # AI gen code getting overly defensive here. Gonna let it ride at this point bc the utilization patterns
    # of these scripts is not clear to the poitn that this would NEVER be run independently so we can't rely on checks further
    # up the call flow. The FE repo should always have things like package.json so it's not really a strong check
    # but who knows what could get messed up. Refinements will be made as we get more clarity on how this is used.
    def validate_cms_local_dev_wiring
      return true unless cms_enabled?

      errors = []
      package_data = frontend_package_data

      if package_data.nil?
        errors << "missing frontend package.json at #{frontend_package_path}"
      else
        workspaces = package_data["workspaces"]
        scripts = package_data["scripts"] || {}

        unless workspaces.is_a?(Array) && workspaces.include?("packages/*")
          errors << "frontend package.json must include workspaces entry packages/*"
        end

        %w[dev content dev:content content:check].each do |script_name|
          errors << "frontend package.json missing scripts.#{script_name}" unless scripts.key?(script_name)
        end
      end

      errors << "missing #{paths.frontend_current_relative_path}/bin/content" unless File.exist?(File.join(paths.frontend_current_path, "bin", "content"))
      errors << "missing #{paths.frontend_current_relative_path}/bin/content-check" unless File.exist?(File.join(paths.frontend_current_path, "bin", "content-check"))
      errors << "missing #{paths.frontend_current_relative_path}/packages/keystatic-admin/package.json" unless File.exist?(File.join(paths.frontend_current_path, "packages", "keystatic-admin", "package.json"))

      return true if errors.empty?

      Workspace.fail_with_help(
        "CMS local dev subsystem is not wired correctly.",
        details: errors.join("; "),
        fixes: [
          "Re-run CMS installer: bin/workspace cms --provider keystatic",
          "Verify frontend scripts include dev/content/dev:content/content:check.",
          "Verify packages/keystatic-admin was scaffolded and dependencies are installed."
        ]
      )
      false
    end

    def cms_enabled?
      manifest = project_manifest
      features = manifest["features"]
      return false unless features.is_a?(Hash)

      cms = features["cms"]
      cms.is_a?(Hash) && cms["enabled"] == true && cms["provider"].to_s == "keystatic"
    end

    def project_manifest
      @project_manifest ||= begin
        path = File.join(workspace_root, "config", "project.yml")
        File.exist?(path) ? (YAML.safe_load_file(path, permitted_classes: [], aliases: false) || {}) : {}
      rescue Psych::SyntaxError
        {}
      end
    end

    def frontend_package_data
      return @frontend_package_data if defined?(@frontend_package_data)

      @frontend_package_data = begin
        return nil unless File.exist?(frontend_package_path)

        JSON.parse(File.read(frontend_package_path))
      rescue JSON::ParserError
        nil
      end
    end

    def frontend_package_path
      File.join(paths.frontend_current_path, "package.json")
    end

    def cms_reachability_check(target)
      Validation::ContentReachability.new(
        root: paths.frontend_current_path,
        target: target,
        stdout: stdout
      ).call
    end

    def backend_ci
      @backend_ci ||= LocalInfrastructure::BackendCI.new(
        backend_path: paths.backend_current_path,
        backend_label: paths.backend_current_relative_path,
        workspace_root: workspace_root,
        stdin: stdin,
        stdout: stdout
      )
    end

    def paths
      @paths ||= ProjectPaths.new(
        product_slug,
        workspace_root: workspace_root,
        repositories: repositories
      )
    end

    def check_runner
      @check_runner ||= Validation::CheckRunner.new
    end

    def report
      @report ||= Validation::Report.new
    end
  end
end
