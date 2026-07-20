# frozen_string_literal: true

module Workspace
  module Services
    module Infra
      # Owns the interactive `bin/infra configure` questionnaire and returns
      # a normalized configuration hash for downstream manifest/tfvars writers.
      class ConfigurationPrompt
        GITHUB_OWNER_PLACEHOLDER = "your-github-org"

        def initialize(prompt:, output:)
          @prompt = prompt
          @output = output
        end

        def call(environment:, defaults:)
          core_app_settings = collect_core_app_settings(defaults)
          git_repo_settings = collect_git_repo_settings(defaults)
          domain_settings = collect_domain_name_settings(defaults)
          infra_components_toggles = collect_infra_component_toggles(defaults)
          blob_store_provider = collect_blob_store_provider(defaults, spaces_enabled: infra_components_toggles.fetch("spaces"))

          {
            "app_name" => core_app_settings.fetch("app_name"),
            "environment" => environment,
            "region" => core_app_settings.fetch("region"),
            "do_region" => core_app_settings.fetch("do_region"),
            "github" => {
              "owner" => git_repo_settings.fetch("owner"),
              "api_repo" => git_repo_settings.fetch("api_repo"),
              "web_repo" => git_repo_settings.fetch("web_repo"),
              "branch" => git_repo_settings.fetch("branch"),
              "auto_deploy" => git_repo_settings.fetch("auto_deploy")
            },
            "frontend_domain" => domain_settings.fetch("frontend_domain"),
            "components" => {
              "api" => true,
              "worker" => true,
              "web" => true,
              "postgres" => infra_components_toggles.fetch("postgres"),
              "opensearch" => infra_components_toggles.fetch("opensearch"),
              "spaces" => infra_components_toggles.fetch("spaces")
            },
            "sizes" => {
              "api" => dig_value(defaults, "sizes", "api") || "basic-xxs",
              "worker" => dig_value(defaults, "sizes", "worker") || "basic-xxs",
              "web" => dig_value(defaults, "sizes", "web") || "basic-xxs",
              "postgres" => dig_value(defaults, "sizes", "postgres") || "db-s-1vcpu-1gb",
              "opensearch" => dig_value(defaults, "sizes", "opensearch")
            },
            "blob_store_provider" => blob_store_provider
          }
        end

        private

        attr_reader :prompt, :output

        def prompt_value(label, default: nil, hint: nil)
          output.puts("  Hint: #{hint}") unless hint.to_s.empty?
          prompt.ask(label, default: default)
        end

        def prompt_bool(label, default:, hint: nil)
          output.puts("  Hint: #{hint}") unless hint.to_s.empty?
          prompt.yes?(label, default: default)
        end

        def collect_core_app_settings(defaults)
          Workspace.info("Step 1/4: Core application settings")
          Workspace.info("These values define app naming and deploy regions.")

          {
            "app_name" => prompt_value(
              "app_name",
              default: dig_value(defaults, "app_name") || default_app_name,
              hint: "Used in Terraform resource names and app identifiers."
            ),
            "region" => prompt_value(
              "region",
              default: dig_value(defaults, "region") || "nyc",
              hint: "App Platform region slug (for example: nyc)."
            ),
            "do_region" => prompt_value(
              "do_region",
              default: dig_value(defaults, "do_region") || "nyc3",
              hint: "DigitalOcean infrastructure region slug (for example: nyc3)."
            )
          }
        end

        def collect_git_repo_settings(defaults)
          Workspace.info("Step 2/4: Source repositories")
          Workspace.info("These repos and branch names are used for App Platform deploy sources.")

          {
            "owner" => prompt_value(
              "github.owner",
              default: preferred_github_owner(defaults),
              hint: "GitHub org/user that owns both API and web repositories."
            ),
            "api_repo" => prompt_value(
              "github.api_repo",
              default: dig_value(defaults, "github", "api_repo") || default_repo_name("backend-api", "api-template"),
              hint: "Repository name only (without owner)."
            ),
            "web_repo" => prompt_value(
              "github.web_repo",
              default: dig_value(defaults, "github", "web_repo") || default_repo_name("frontend-web-client", "web-template"),
              hint: "Repository name only (without owner)."
            ),
            "branch" => prompt_value(
              "github.branch",
              default: dig_value(defaults, "github", "branch") || "main",
              hint: "Branch App Platform should auto-deploy from."
            ),
            "auto_deploy" => prompt_bool(
              "github.auto_deploy",
              default: dig_value(defaults, "github", "auto_deploy", fallback: false),
              hint: "Enable automatic deploys on push for backend and frontend apps."
            )
          }
        end

        def collect_infra_component_toggles(defaults)
          Workspace.info("Step 3/4: Component toggles")
          Workspace.info("Disable components only if you plan to provide equivalent external services. This does not currently support arbitrary infra configuration, but may in the future.")

          {
            "postgres" => prompt_bool(
              "components.postgres",
              default: dig_value(defaults, "components", "postgres", fallback: true),
              hint: "Enable managed PostgreSQL provisioning."
            ),
            "opensearch" => prompt_bool(
              "components.opensearch",
              default: dig_value(defaults, "components", "opensearch", fallback: true),
              hint: "Enable managed OpenSearch provisioning."
            ),
            "spaces" => prompt_bool(
              "components.spaces",
              default: dig_value(defaults, "components", "spaces", fallback: true),
              hint: "Enable blob storage env wiring and optional provisioning."
            )
          }
        end

        def collect_domain_name_settings(defaults)
          Workspace.info("Step 3/5: Frontend domain (optional)")
          Workspace.info("If provided, this domain should already be provisioned and routed to the frontend app.")

          {
            "frontend_domain" => prompt_value(
              "frontend_domain",
              default: dig_value(defaults, "frontend_domain") || "",
              hint: "Optional custom frontend domain (for example: app.example.com). Leave blank to use DigitalOcean temporary ingress as a fallback."
            ).to_s.strip
          }
        end

        def collect_blob_store_provider(defaults, spaces_enabled:)
          Workspace.info("Step 5/5: Blob storage provider")
          Workspace.info("Use digitalocean_spaces for managed provisioning, or aws_s3 for external bucket/credentials.")

          provider = prompt_value(
            "blob_store_provider (digitalocean_spaces|aws_s3)",
            default: dig_value(defaults, "blob_store_provider") || "digitalocean_spaces",
            hint: "aws_s3 mode expects AWS CLI auth and bucket credentials to be available."
          )

          if spaces_enabled && provider == "aws_s3"
            Workspace.info("Hint: run 'bin/infra doctor' after configure to verify AWS CLI and auth readiness.")
          end

          provider
        end

        def dig_value(hash, *keys, fallback: nil)
          value = keys.reduce(hash) do |memo, key|
            break nil unless memo.is_a?(Hash)

            memo[key]
          end
          value.nil? ? fallback : value
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

        def preferred_github_owner(defaults)
          configured_owner = dig_value(defaults, "github", "owner").to_s.strip
          return configured_owner unless github_owner_placeholder?(configured_owner)

          inferred_owner = default_github_owner.to_s.strip
          return inferred_owner unless github_owner_placeholder?(inferred_owner)

          detected_owner = github_cli_owner
          return detected_owner unless detected_owner.empty?

          GITHUB_OWNER_PLACEHOLDER
        end

        def github_owner_placeholder?(owner)
          owner.to_s.strip.empty? || owner.to_s.strip == GITHUB_OWNER_PLACEHOLDER
        end

        def github_cli_owner
          return "" unless Workspace.command_exists?("gh")

          output, success = Workspace.capture("gh api user -q .login")
          return "" unless success

          output.to_s.strip
        end

        def default_app_name
          File.basename(Workspace::ROOT).sub(/-workspace\z/, "")
        end
      end
    end
  end
end