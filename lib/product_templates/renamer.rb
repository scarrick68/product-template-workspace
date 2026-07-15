#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
require "fileutils"
require "shellwords"
require_relative "../workspace"
require_relative "./project_paths"

module ProductTemplates
  class Renamer
    attr_reader :product_slug, :workspace_root, :repositories

    def initialize(product_slug, workspace_root: Workspace::ROOT, repositories: Workspace.repositories)
      @product_slug = product_slug.to_s.strip
      @workspace_root = workspace_root
      @repositories = repositories
    end

    def call
      validate_product_slug!
      run_repo_renamers
      rename_repo_directories
      update_project_manifest_repo_config
      update_workspace_repo_config
      print_summary
      0
    end

    private

    def validate_product_slug!
      return if product_slug.match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/)

      Workspace.abort_with_help(
        "Invalid product name.",
        details: "Expected kebab-case (example: my-super-app), received '#{product_slug}'.",
        fixes: [
          "Use lowercase letters, numbers, and single dashes.",
          "Try: bin/new_product my-super-app"
        ]
      )
    end

    def paths
      @paths ||= ProjectPaths.new(
        product_slug,
        workspace_root: workspace_root,
        repositories: repositories
      )
    end

    def run_repo_renamers
      run_repo_renamer(backend_paths)
      run_repo_renamer(frontend_paths)
    end

    def run_repo_renamer(repo)
      unless Dir.exist?(repo[:current_path])
        Workspace.abort_with_help(
          "#{repo[:label]} repository path is missing.",
          details: "Expected #{repo[:current_relative_path]}",
          fixes: [
            "Confirm template repositories are checked out under repos/.",
            "Run bin/bootstrap before attempting product rename."
          ]
        )
      end

      unless File.executable?(repo[:rename_script_path])
        Workspace.abort_with_help(
          "#{repo[:label]} rename script is missing or not executable.",
          details: "Expected executable script at #{repo[:rename_script_relative]}",
          fixes: [
            "Add or chmod +x the repo-local rename script.",
            "Re-run bin/new_product after fixing script permissions."
          ]
        )
      end

      Workspace.ok("running #{repo[:label]} rename tool")
      Workspace.run(
        "bin/template_rename #{Shellwords.escape(repo[:template_name])} #{Shellwords.escape(repo[:target_name])}",
        chdir: repo[:current_path]
      )
    end

    def rename_repo_directories
      rename_repo_directory(backend_paths)
      rename_repo_directory(frontend_paths)
    end

    def rename_repo_directory(repo)
      if repo[:current_path] == repo[:target_path]
        Workspace.info("repository path unchanged for #{repo[:target_name]}")
        return
      end

      if Dir.exist?(repo[:target_path])
        Workspace.warn("target repository path already exists: #{repo[:target_relative_path]}")
        return unless Dir.exist?(repo[:current_path])

        Workspace.abort_with_help(
          "Cannot rename #{repo[:template_name]}; destination already exists.",
          details: "Both #{repo[:current_relative_path]} and #{repo[:target_relative_path]} are present.",
          fixes: [
            "Move or remove one of the directories.",
            "Re-run bin/new_product once repository paths are unambiguous."
          ]
        )
      end

      unless Dir.exist?(repo[:current_path])
        Workspace.warn("source repository path missing; skipping move: #{repo[:current_relative_path]}")
        return
      end

      FileUtils.mv(repo[:current_path], repo[:target_path])
      Workspace.ok("renamed repo directory #{repo[:template_name]} -> #{repo[:target_name]}")
    end

    def backend_paths
      {
        label: "API",
        template_name: "api-template",
        target_name: paths.backend_app_name,
        current_relative_path: paths.backend_current_relative_path,
        current_path: paths.backend_current_path,
        target_relative_path: paths.backend_app_relative_path,
        target_path: paths.backend_app_path,
        rename_script_relative: paths.backend_rename_script_relative,
        rename_script_path: paths.backend_rename_script_path
      }
    end

    def frontend_paths
      {
        label: "WEB",
        template_name: "web-template",
        target_name: paths.frontend_app_name,
        current_relative_path: paths.frontend_current_relative_path,
        current_path: paths.frontend_current_path,
        target_relative_path: paths.frontend_app_relative_path,
        target_path: paths.frontend_app_path,
        rename_script_relative: paths.frontend_rename_script_relative,
        rename_script_path: paths.frontend_rename_script_path
      }
    end

    def update_project_manifest_repo_config
      manifest_path = File.join(workspace_root, "config", "project.yml")
      return unless File.exist?(manifest_path)

      manifest = YAML.safe_load(File.read(manifest_path), permitted_classes: [], aliases: false) || {}
      repositories_section = manifest["repositories"]
      return unless repositories_section

      case repositories_section
      when Hash
        repositories_section.each_value { |repo| paths.update_repo_entry!(repo) if repo.is_a?(Hash) }
      when Array
        repositories_section.each { |repo| paths.update_repo_entry!(repo) if repo.is_a?(Hash) }
      end

      File.write(manifest_path, YAML.dump(manifest))
      Workspace.ok("updated config/project.yml with renamed repository paths")
    end

    def update_workspace_repo_config
      repos_config_path = File.join(workspace_root, "config", "repos.yml")
      config = if File.exist?(repos_config_path)
                 YAML.safe_load(File.read(repos_config_path), permitted_classes: [], aliases: false) || {}
               else
                 {}
               end

      repos = config["repositories"]
      return unless repos.is_a?(Array)

      repos.each do |repo|
        paths.update_repo_entry!(repo)
      end

      File.write(repos_config_path, YAML.dump(config))
      Workspace.ok("updated config/repos.yml with renamed repository paths")
    end

    def print_summary
      puts
      Workspace.ok("product rename complete")
      Workspace.info("API repository: #{paths.backend_app_relative_path}")
      Workspace.info("WEB repository: #{paths.frontend_app_relative_path}")
    end
  end
end
