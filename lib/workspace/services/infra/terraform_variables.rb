# frozen_string_literal: true

module Workspace
  module Services
    module Infra
      # Pure transformation from normalized infra configuration to Terraform tfvars.
      # Allows Ruby scripts to inform Terraform configuration where needed.
      class TerraformVariables
        def initialize(configuration)
          @configuration = configuration
        end

        def to_h
          {
            "project_name" => app_name,
            "rails_app_name" => github.fetch("api_repo", "#{app_name}-api"),
            "app_region" => configuration.fetch("region"),
            "web_instance_size_slug" => sizes.fetch("api", "basic-xxs"),
            "worker_instance_size_slug" => sizes.fetch("worker", "basic-xxs"),
            "frontend_app_name" => github.fetch("web_repo", "#{app_name}-web"),
            "frontend_repo" => frontend_repo,
            "frontend_branch" => github.fetch("branch", "main"),
            "frontend_web_instance_size_slug" => sizes.fetch("web", "basic-xxs"),
            "postgres_name" => "#{app_name}-postgres",
            "postgres_region" => do_region,
            "postgres_size" => sizes.fetch("postgres", "db-s-1vcpu-1gb"),
            "opensearch_name" => "#{app_name}-opensearch",
            "opensearch_region" => do_region,
            "opensearch_size" => sizes.fetch("opensearch"),
            "enable_spaces" => spaces_enabled?,
            "spaces_provider" => blob_store_provider,
            "spaces_region" => do_region,
            "spaces_bucket_name" => default_spaces_bucket_name
          }
        end

        private

        attr_reader :configuration

        def app_name
          configuration.fetch("app_name")
        end

        def do_region
          configuration.fetch("do_region")
        end

        def github
          configuration.fetch("github", {})
        end

        def sizes
          configuration.fetch("sizes", {})
        end

        def frontend_repo
          owner = github["owner"].to_s.strip
          repo = github["web_repo"].to_s.strip
          [owner, repo].reject(&:empty?).join("/")
        end

        def spaces_enabled?
          components = configuration.fetch("components", {})
          components.fetch("spaces", true)
        end

        def blob_store_provider
          provider = configuration.fetch("blob_store_provider", "digitalocean_spaces").to_s.strip
          provider.empty? ? "digitalocean_spaces" : provider
        end

        def default_spaces_bucket_name
          sanitized = app_name.downcase.gsub(/[^a-z0-9-]/, "-").gsub(/-+/, "-").gsub(/\A-|-\z/, "")
          normalized = sanitized.empty? ? "workspace" : sanitized
          "#{normalized}-artifacts"
        end
      end
    end
  end
end