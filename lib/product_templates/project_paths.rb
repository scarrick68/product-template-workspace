#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../workspace"

module ProductTemplates
  class ProjectPaths
    BACKEND_PURPOSE = "backend-api"
    FRONTEND_PURPOSE = "frontend-web-client"

    attr_reader :product_slug, :workspace_root

    def initialize(product_slug, workspace_root:, repositories:)
      @product_slug = product_slug
      @workspace_root = workspace_root
      @repositories = repositories
    end

    def backend_app_name
      "#{product_slug}-api"
    end

    def frontend_app_name
      "#{product_slug}-web"
    end

    def backend_current_relative_path
      backend_repo.fetch("path")
    end

    def frontend_current_relative_path
      frontend_repo.fetch("path")
    end

    def backend_current_path
      absolute_path(backend_current_relative_path)
    end

    def frontend_current_path
      absolute_path(frontend_current_relative_path)
    end

    def backend_app_relative_path
      sibling_path(backend_current_relative_path, backend_app_name)
    end

    def frontend_app_relative_path
      sibling_path(frontend_current_relative_path, frontend_app_name)
    end

    def backend_app_path
      absolute_path(backend_app_relative_path)
    end

    def frontend_app_path
      absolute_path(frontend_app_relative_path)
    end

    def backend_rename_script_relative
      File.join(backend_current_relative_path, "bin", "template_rename")
    end

    def frontend_rename_script_relative
      File.join(frontend_current_relative_path, "bin", "template_rename")
    end

    def backend_rename_script_path
      absolute_path(backend_rename_script_relative)
    end

    def frontend_rename_script_path
      absolute_path(frontend_rename_script_relative)
    end

    def update_repo_entry!(repo)
      case repo["purpose"]
      when BACKEND_PURPOSE
        update_repo(repo, backend_app_name)
      when FRONTEND_PURPOSE
        update_repo(repo, frontend_app_name)
      end
    end

    private

    attr_reader :repositories

    def backend_repo
      @backend_repo ||= repository_for_purpose(BACKEND_PURPOSE)
    end

    def frontend_repo
      @frontend_repo ||= repository_for_purpose(FRONTEND_PURPOSE)
    end

    def repository_for_purpose(purpose)
      repo = repositories.find { |entry| entry["purpose"].to_s == purpose }

      unless repo
        Workspace.abort_with_help(
          "Repository configuration missing for purpose '#{purpose}'.",
          details: "Could not find repository entry with purpose '#{purpose}' in config/repos.yml.",
          fixes: [
            "Add a repository entry with purpose '#{purpose}' in config/repos.yml.",
            "Ensure required keys are present: name, path, github."
          ]
        )
      end

      repo
    end

    def absolute_path(relative_path)
      File.join(workspace_root, relative_path)
    end

    def sibling_path(current_relative_path, target_name)
      parent = File.dirname(current_relative_path)
      File.join(parent, target_name)
    end

    def update_repo(repo, app_name)
      current_path = repo["path"].to_s
      parent = File.dirname(current_path)
      repo["name"] = app_name
      repo["path"] = File.join(parent, app_name)
      repo["github"] = replace_github_repo_name(repo["github"], app_name) if repo["github"]
    end

    def replace_github_repo_name(github_slug, new_repo_name)
      github_slug.to_s.sub(%r{/[^/]+\z}, "/#{new_repo_name}")
    end
  end
end