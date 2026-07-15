#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../workspace"
require_relative "./project_paths"
require_relative "./local_infrastructure/backend_ci"
require_relative "./validation/check"
require_relative "./validation/check_runner"
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
      return 1 unless backend_ci.prepare

      results = check_runner.run(check_definitions)
      report.print(results)

      results.all?(&:passed?) ? 0 : 1
    end

    private

    def check_definitions
      [
        check("API CI", "bin/ci", paths.backend_current_path, paths.backend_current_relative_path),
        check("WEB lint", "npm run lint", paths.frontend_current_path, paths.frontend_current_relative_path),
        check("WEB tests", "npm run test", paths.frontend_current_path, paths.frontend_current_relative_path),
        check("WEB build", "npm run build", paths.frontend_current_path, paths.frontend_current_relative_path),
        check("Workspace status", "bin/status", workspace_root, ".")
      ]
    end

    def check(name, command, directory, directory_label)
      Validation::Check.new(
        name: name,
        command: command,
        directory: directory,
        directory_label: directory_label
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
