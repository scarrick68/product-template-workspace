#!/usr/bin/env ruby
# frozen_string_literal: true

module Workspace
  module Commands
    module Infra
      class TfvarsBuilder
        DIGITALOCEAN_TOKEN_KEY = "DIGITALOCEAN_ACCESS_TOKEN"
        SPACES_ACCESS_KEY_ID_KEY = "SPACES_ACCESS_KEY_ID"
        SPACES_SECRET_ACCESS_KEY_KEY = "SPACES_SECRET_ACCESS_KEY"

        def initialize(default_opensearch_size:, token_fetcher:, env: ENV)
          @default_opensearch_size = default_opensearch_size
          @token_fetcher = token_fetcher
          @env = env
        end

        def build(config)
          config = config || {}
          spaces_provider = config.fetch("spaces_provider", "digitalocean_spaces")
          project = config.fetch("project", {})
          components = config.fetch("components", {})
          sizes = config.fetch("sizes", {})
          github = config.fetch("github", {})

          spaces_access_key, spaces_secret_key = resolved_spaces_credentials
          bucket_name = resolved_bucket_name(config["app_name"], config["environment"], env["DATA_ARTIFACT_BUCKET"])
          endpoint = resolved_spaces_endpoint(config["do_region"])

          {
            "digitalocean_access_token" => digitalocean_token_or_placeholder,
            "spaces_access_key_id" => spaces_access_key,
            "spaces_secret_access_key" => spaces_secret_key,
            "app_name" => config["app_name"],
            "environment" => config["environment"],
            "region" => config["region"],
            "do_region" => config["do_region"],
            "project_name" => project["name"] || "#{config["app_name"]}-#{config["environment"]}",
            "project_environment" => project["environment"] || config["environment"],
            "project_purpose" => project["purpose"] || "Web Application",
            "github_owner" => github["owner"],
            "api_repo" => github["api_repo"],
            "web_repo" => github["web_repo"],
            "branch" => github["branch"],
            "enable_api" => components.fetch("api", true),
            "enable_worker" => components.fetch("worker", true),
            "enable_web" => components.fetch("web", true),
            "api_instance_size_slug" => sizes.fetch("api", "basic-xxs"),
            "worker_instance_size_slug" => sizes.fetch("worker", "basic-xxs"),
            "web_instance_size_slug" => sizes.fetch("web", "basic-xxs"),
            "enable_postgres" => components.fetch("postgres", true),
            "postgres_size_slug" => sizes.fetch("postgres", "db-s-1vcpu-1gb"),
            "enable_opensearch" => components.fetch("opensearch", true),
            "opensearch_size_slug" => sizes.fetch("opensearch", default_opensearch_size),
            "enable_spaces" => components.fetch("spaces", true),
            "spaces_provider" => spaces_provider,
            "rails_master_key" => env_or_placeholder("RAILS_MASTER_KEY"),
            "active_storage_service" => components.fetch("spaces", true) ? "amazon" : nil,
            "data_artifact_bucket" => bucket_name,
            "s3_endpoint" => endpoint,
            "aws_access_key_id" => env["AWS_ACCESS_KEY_ID"] || spaces_access_key,
            "aws_secret_access_key" => env["AWS_SECRET_ACCESS_KEY"] || spaces_secret_key
          }
        end

        private

        attr_reader :default_opensearch_size, :token_fetcher, :env

        def env_or_placeholder(name)
          value = env[name].to_s.strip
          return value unless value.empty?

          "<set-#{name.downcase}>"
        end

        def digitalocean_token_or_placeholder
          token = token_fetcher.call
          return token if token

          env_or_placeholder(DIGITALOCEAN_TOKEN_KEY)
        end

        def resolved_spaces_credentials
          access_key = env[SPACES_ACCESS_KEY_ID_KEY].to_s.strip
          secret_key = env[SPACES_SECRET_ACCESS_KEY_KEY].to_s.strip

          [presence_or_nil(access_key), presence_or_nil(secret_key)]
        end

        def resolved_bucket_name(app_name, environment, configured_bucket)
          bucket = configured_bucket.to_s.strip
          return bucket unless bucket.empty?

          slug = "#{app_name}-#{environment}-artifacts"
          slug.downcase.gsub("_", "-")[0, 63]
        end

        def resolved_spaces_endpoint(do_region)
          region = do_region.to_s.strip
          region = "nyc3" if region.empty?
          "https://#{region}.digitaloceanspaces.com"
        end

        def presence_or_nil(value)
          stripped = value.to_s.strip
          stripped.empty? ? nil : stripped
        end
      end
    end
  end
end
