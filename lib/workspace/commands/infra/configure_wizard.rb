#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../../../workspace"
require_relative "../../../workspace/cli_prompt"

module Workspace
  module Commands
    module Infra
      class ConfigureWizard
        BLOB_STORE_PROVIDERS = %w[digitalocean_spaces aws_s3].freeze

        def initialize(stdin: $stdin, stdout: $stdout, default_opensearch_size: "db-s-1vcpu-2gb")
          @stdin = stdin
          @stdout = stdout
          @default_opensearch_size = default_opensearch_size
          @prompt = Workspace::CliPrompt.new(stdin: @stdin, stdout: @stdout)
        end

        def collect(environment:, existing: {})
          app_name = collect_app_name(existing)
          region, do_region = collect_regions(existing)
          project = collect_project(existing, app_name: app_name, environment: environment)
          github = collect_github_data(existing)
          components = collect_infra_component_toggles(existing)
          spaces_provider = collect_blob_store_provider(existing, spaces_enabled: components["spaces"])
          sizes = collect_sizes(existing)

          {
            "app_name" => app_name,
            "environment" => environment,
            "region" => region,
            "do_region" => do_region,
            "project" => project,
            "github" => github,
            "components" => components,
            "sizes" => sizes,
            "spaces_provider" => spaces_provider
          }
        end

        private

        attr_reader :stdin, :stdout, :default_opensearch_size, :prompt

        def collect_app_name(existing)
          Workspace.info("Step 1/4: Core application settings")
          Workspace.info("These values define app naming and deploy regions.")
          prompt_value(
            "app_name",
            default: dig_value(existing, "app_name") || default_app_name,
            hint: "Used in Terraform resource names and app identifiers."
          )
        end

        def collect_regions(existing)
          region = prompt_value(
            "region",
            default: dig_value(existing, "region") || "nyc",
            hint: "App Platform region slug (for example: nyc)."
          )
          do_region = prompt_value(
            "do_region",
            default: dig_value(existing, "do_region") || "nyc3",
            hint: "DigitalOcean infrastructure region slug (for example: nyc3)."
          )

          [region, do_region]
        end

        def collect_github_data(existing)
          Workspace.info("Step 2/4: Source repositories")
          Workspace.info("These repos and branch names are used for App Platform deploy sources.")
          {
            "owner" => prompt_value(
              "github.owner",
              default: dig_value(existing, "github", "owner") || default_github_owner,
              hint: "GitHub org/user that owns both API and web repositories."
            ),
            "api_repo" => prompt_value(
              "github.api_repo",
              default: dig_value(existing, "github", "api_repo") || default_repo_name("backend-api", "api-template"),
              hint: "Repository name only (without owner)."
            ),
            "web_repo" => prompt_value(
              "github.web_repo",
              default: dig_value(existing, "github", "web_repo") || default_repo_name("frontend-web-client", "web-template"),
              hint: "Repository name only (without owner)."
            ),
            "branch" => prompt_value(
              "github.branch",
              default: dig_value(existing, "github", "branch") || "main",
              hint: "Branch App Platform should auto-deploy from."
            ),
            "auto_deploy" => true
          }
        end

        def collect_project(existing, app_name:, environment:)
          existing_project = dig_value(existing, "project", fallback: {})

          {
            "name" => dig_value(existing_project, "name") || "#{app_name}-#{environment}",
            "environment" => dig_value(existing_project, "environment") || environment,
            "purpose" => dig_value(existing_project, "purpose") || "Web Application"
          }
        end

        def collect_infra_component_toggles(existing)
          Workspace.info("Step 3/4: Component toggles")
          Workspace.info("Disable components only if you plan to provide equivalent external services.")
          {
            "api" => true,
            "worker" => true,
            "web" => true,
            "postgres" => prompt_bool(
              "components.postgres",
              default: dig_value(existing, "components", "postgres", fallback: true),
              hint: "Enable managed PostgreSQL provisioning."
            ),
            "opensearch" => prompt_bool(
              "components.opensearch",
              default: dig_value(existing, "components", "opensearch", fallback: true),
              hint: "Enable managed OpenSearch provisioning."
            ),
            "spaces" => prompt_bool(
              "components.spaces",
              default: dig_value(existing, "components", "spaces", fallback: true),
              hint: "Enable blob storage env wiring and optional provisioning."
            )
          }
        end

        def collect_blob_store_provider(existing, spaces_enabled:)
          Workspace.info("Step 4/4: Blob storage provider")
          Workspace.info("Use digitalocean_spaces for managed provisioning, or aws_s3 for external bucket/credentials.")
          spaces_provider = prompt_enum(
            "spaces_provider (digitalocean_spaces|aws_s3)",
            default: dig_value(existing, "spaces_provider") || "digitalocean_spaces",
            hint: "aws_s3 mode expects AWS CLI auth and bucket credentials to be available.",
            valid_values: BLOB_STORE_PROVIDERS
          )

          if spaces_enabled && spaces_provider == "aws_s3"
            Workspace.info("Hint: run 'bin/infra doctor production --phase=config' after configure to verify AWS CLI and auth readiness.")
          end

          spaces_provider
        end

        def collect_sizes(existing)
          {
            "api" => dig_value(existing, "sizes", "api") || "basic-xxs",
            "worker" => dig_value(existing, "sizes", "worker") || "basic-xxs",
            "web" => dig_value(existing, "sizes", "web") || "basic-xxs",
            "postgres" => dig_value(existing, "sizes", "postgres") || "db-s-1vcpu-1gb",
            "opensearch" => dig_value(existing, "sizes", "opensearch") || default_opensearch_size
          }
        end

        def prompt_value(label, default: nil, hint: nil)
          prompt.value(label, default: default, hint: hint)
        end

        def prompt_bool(label, default:, hint: nil)
          prompt.bool(label, default: default, hint: hint)
        end

        def prompt_enum(label, default:, hint:, valid_values:)
          prompt.enum(label, default: default, hint: hint, valid_values: valid_values)
        end

        def default_repo_name(purpose, fallback)
          repo = Workspace.repositories.find { |item| item["purpose"].to_s == purpose }
          return fallback unless repo

          repo["name"].to_s.empty? ? fallback : repo["name"].to_s
        end

        def default_github_owner
          backend = Workspace.repositories.find { |item| item["purpose"].to_s == "backend-api" }
          github = backend && backend["github"].to_s
          owner = github.split("/", 2).first
          return nil if owner.nil? || owner.empty?

          owner
        end

        def default_app_name
          File.basename(Workspace::ROOT).sub(/-workspace\z/, "")
        end

        def dig_value(hash, *keys, fallback: nil)
          value = keys.reduce(hash) do |memo, key|
            break nil unless memo.is_a?(Hash)

            memo[key]
          end
          value.nil? ? fallback : value
        end
      end
    end
  end
end