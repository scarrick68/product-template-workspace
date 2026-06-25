#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../workspace"
require_relative "./project_paths"

module ProductTemplates
  class Validator
    attr_reader :product_slug, :workspace_root

    def initialize(product_slug, workspace_root: Workspace::ROOT)
      @product_slug = product_slug.to_s.strip
      @workspace_root = workspace_root
    end

    def call
      validate_product_slug!

      checks = [
        check("API CI", "bin/ci", chdir: paths.backend_current_path, chdir_label: paths.backend_current_relative_path),
        check("WEB lint", "npm run lint", chdir: paths.frontend_current_path, chdir_label: paths.frontend_current_relative_path),
        check("WEB tests", "npm run test", chdir: paths.frontend_current_path, chdir_label: paths.frontend_current_relative_path),
        check("WEB build", "npm run build", chdir: paths.frontend_current_path, chdir_label: paths.frontend_current_relative_path),
        check("Workspace status", "bin/status", chdir: workspace_root, chdir_label: ".")
      ]

      print_checklist(checks)
      print_manual_steps

      checks.all? { |item| item[:ok] } ? 0 : 1
    end

    private

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

    def paths
      @paths ||= ProjectPaths.new(
        product_slug,
        workspace_root: workspace_root,
        repositories: Workspace.repositories
      )
    end

    def check(name, command, chdir:, chdir_label: nil)
      path_label = chdir_label || chdir
      if !Dir.exist?(chdir)
        Workspace.warn("#{name} skipped: missing directory #{path_label}")
        return { name: name, ok: false, note: "missing #{path_label}" }
      end

      ok = Workspace.run(command, chdir: chdir, allow_failure: true)
      { name: name, ok: ok, note: ok ? "passed" : "failed" }
    end

    def print_checklist(checks)
      puts
      Workspace.ok("Template -> Product Handoff Checklist")
      checks.each do |item|
        marker = item[:ok] ? "[x]" : "[ ]"
        puts "  #{marker} #{item[:name]} (#{item[:note]})"
      end
    end

    def print_manual_steps
      puts
      Workspace.warn("Manual follow-up required:")
      puts "  [ ] Verify GitHub repo names and remote origins for renamed apps."
      puts "  [ ] Verify deployment app/project names and secrets."
      puts "  [ ] Run bin/sync-openapi and confirm contract consumers still resolve paths."
      puts "  [ ] Smoke test local startup with bin/bootstrap and bin/start-day."
    end
  end
end
