# frozen_string_literal: true

require_relative "../../../workspace/project_manifest/loader"

module Workspace
  module Services
    module Infra
      # Reads and writes environment infrastructure settings in config/project.yml.
      class ManifestConfiguration
        MANIFEST_PATH = File.join("config", "project.yml")
        TEMPLATE_PROJECT_SLUG = "product-template-workspace"
        TEMPLATE_APP_NAME = "my-product"

        def initialize(root: Workspace::ROOT)
          @root = root
        end

        def read(environment:)
          manifest = load_manifest
          return {} if manifest.empty?

          infrastructure = dig_value(manifest, "environments", environment, "infrastructure") || {}
          project_slug = dig_value(manifest, "project", "slug")
          default_environment = dig_value(manifest, "project", "default_environment") || "production"
          inferred_app_name = inferred_app_name_from_repositories(manifest)

          {
            "app_name" => resolved_app_name(
              infrastructure,
              project_slug,
              inferred_app_name,
              environment,
              default_environment
            ),
            "project_slug" => project_slug,
            "installation_id" => dig_value(manifest, "project", "installation_id"),
            "environment" => environment,
            "region" => infrastructure["app_region"] || "nyc",
            "do_region" => infrastructure["region"] || infrastructure["do_region"] || "nyc3",
            "frontend_domain" => infrastructure["frontend_domain"].to_s.strip,
            "github" => {
              "owner" => dig_value(infrastructure, "github", "owner") || default_github_owner(manifest),
              "api_repo" => repository_name_from_manifest(manifest, "api", "api-template"),
              "web_repo" => repository_name_from_manifest(manifest, "web", "web-template"),
              "branch" => dig_value(infrastructure, "deployment", "branch") || "main",
              "auto_deploy" => dig_value(infrastructure, "deployment", "auto_deploy", fallback: true)
            },
            "components" => {
              "api" => dig_value(infrastructure, "components", "api", "enabled", fallback: true),
              "worker" => dig_value(infrastructure, "components", "worker", "enabled", fallback: true),
              "web" => dig_value(infrastructure, "components", "web", "enabled", fallback: true),
              "postgres" => dig_value(infrastructure, "components", "postgres", "enabled", fallback: true),
              "opensearch" => dig_value(infrastructure, "components", "opensearch", "enabled", fallback: true),
              "spaces" => dig_value(infrastructure, "components", "spaces", "enabled", fallback: true)
            },
            "sizes" => {
              "api" => dig_value(infrastructure, "components", "api", "size") || "basic-xxs",
              "worker" => dig_value(infrastructure, "components", "worker", "size") || "basic-xxs",
              "web" => dig_value(infrastructure, "components", "web", "size") || "basic-xxs",
              "postgres" => dig_value(infrastructure, "components", "postgres", "size") || "db-s-1vcpu-1gb",
              "opensearch" => dig_value(infrastructure, "components", "opensearch", "size")
            },
            "blob_store_provider" => dig_value(infrastructure, "components", "spaces", "provider") || "digitalocean_spaces"
          }
        end

        def write(environment:, configuration:)
          manifest = load_manifest

          manifest["project"] ||= {}
          manifest["repositories"] ||= {}
          manifest["services"] ||= {}
          manifest["environments"] ||= {}
          manifest["environments"][environment] ||= {}

          existing_infrastructure = manifest["environments"][environment]["infrastructure"] || {}

          manifest["environments"][environment]["infrastructure"] = existing_infrastructure.merge(
            "provider" => existing_infrastructure["provider"] || "digitalocean",
            "app_name" => configuration.fetch("app_name"),
            "region" => configuration.fetch("do_region"),
            "app_region" => configuration.fetch("region"),
            "frontend_domain" => configuration.fetch("frontend_domain", "").to_s.strip,
            "github" => {
              "owner" => dig_value(configuration, "github", "owner").to_s
            },
            "deployment" => {
              "branch" => dig_value(configuration, "github", "branch") || "main",
              "auto_deploy" => true
            },
            "components" => {
              "api" => {
                "enabled" => dig_value(configuration, "components", "api", fallback: true),
                "service" => "api",
                "size" => dig_value(configuration, "sizes", "api") || "basic-xxs"
              },
              "worker" => {
                "enabled" => dig_value(configuration, "components", "worker", fallback: true),
                "service" => "api",
                "size" => dig_value(configuration, "sizes", "worker") || "basic-xxs"
              },
              "web" => {
                "enabled" => dig_value(configuration, "components", "web", fallback: true),
                "service" => "web",
                "size" => dig_value(configuration, "sizes", "web") || "basic-xxs"
              },
              "postgres" => {
                "enabled" => dig_value(configuration, "components", "postgres", fallback: true),
                "size" => dig_value(configuration, "sizes", "postgres") || "db-s-1vcpu-1gb"
              },
              "opensearch" => {
                "enabled" => dig_value(configuration, "components", "opensearch", fallback: true),
                "size" => dig_value(configuration, "sizes", "opensearch") || "db-s-1vcpu-2gb"
              },
              "spaces" => {
                "enabled" => dig_value(configuration, "components", "spaces", fallback: true),
                "provider" => configuration.fetch("blob_store_provider", "digitalocean_spaces")
              }
            }
          )

          File.write(manifest_path, manifest.to_yaml)
        end

        private

        attr_reader :root

        def load_manifest
          Workspace::ProjectManifest::Loader.new(root: root).load || {}
        rescue Workspace::ProjectManifest::InvalidManifest
          {}
        end

        def manifest_path
          File.join(root, MANIFEST_PATH)
        end

        def repository_name_from_manifest(manifest, key, fallback)
          repos = manifest["repositories"]
          return fallback unless repos.is_a?(Hash)

          repo = repos[key]
          return fallback unless repo.is_a?(Hash)

          name = repo["name"].to_s.strip
          name.empty? ? fallback : name
        end

        def default_github_owner(manifest)
          api_repo = dig_value(manifest, "repositories", "api")
          github = api_repo.is_a?(Hash) ? api_repo["github"].to_s : ""
          owner = github.split("/", 2).first
          return nil if owner.nil? || owner.empty?

          owner
        end

        def default_app_name
          File.basename(root).sub(/-workspace\z/, "")
        end

        def resolved_app_name(infrastructure, project_slug, inferred_app_name, environment, default_environment)
          configured_name = infrastructure["app_name"].to_s.strip
          slug_name = project_slug.to_s.strip
          inferred_name = inferred_app_name.to_s.strip
          derived_name = derive_app_name(slug_name: slug_name, environment: environment, default_environment: default_environment)

          if placeholder_app_name?(configured_name)
            if slug_name == TEMPLATE_PROJECT_SLUG && !inferred_name.empty?
              return inferred_name
            end

            return derived_name unless derived_name.empty?
            return inferred_name
          end

          return configured_name unless configured_name.empty?
          return derived_name unless derived_name.empty?
          return slug_name unless slug_name.empty?
          return inferred_name unless inferred_name.empty?

          default_app_name
        end

        def derive_app_name(slug_name:, environment:, default_environment:)
          return "" if slug_name.to_s.strip.empty?

          env_name = environment.to_s.strip
          default_env_name = default_environment.to_s.strip
          return slug_name if env_name.empty? || default_env_name.empty? || env_name == default_env_name

          "#{slug_name}-#{env_name}"
        end

        def inferred_app_name_from_repositories(manifest)
          api_repo_name = repository_name_from_manifest(manifest, "api", "").to_s.strip
          web_repo_name = repository_name_from_manifest(manifest, "web", "").to_s.strip

          api_candidate = api_repo_name.sub(/-api\z/, "") if api_repo_name.end_with?("-api")
          web_candidate = web_repo_name.sub(/-web\z/, "") if web_repo_name.end_with?("-web")

          [api_candidate, web_candidate].find { |value| !value.to_s.strip.empty? }.to_s
        end

        def placeholder_app_name?(configured_name)
          [TEMPLATE_APP_NAME, TEMPLATE_PROJECT_SLUG].include?(configured_name)
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