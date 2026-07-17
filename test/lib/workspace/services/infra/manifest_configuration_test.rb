# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "yaml"

require_relative "../../../../test_helper"
require_relative "../../../../../lib/workspace/services/infra/manifest_configuration"

class ManifestConfigurationTest < Minitest::Test
  def test_read_returns_normalized_configuration_from_manifest
    Dir.mktmpdir("manifest-config-test") do |root|
      write_manifest(root, base_manifest.deep_merge(
        "environments" => {
          "production" => {
            "infrastructure" => {
              "provider" => "digitalocean",
              "app_name" => "my-product",
              "region" => "sfo3",
              "app_region" => "sfo",
              "github" => { "owner" => "acme" },
              "deployment" => { "branch" => "release", "auto_deploy" => false },
              "components" => {
                "api" => { "enabled" => true, "size" => "basic-xxs" },
                "worker" => { "enabled" => false, "size" => "basic-xs" },
                "web" => { "enabled" => true, "size" => "basic-s" },
                "postgres" => { "enabled" => true, "size" => "db-s-1vcpu-2gb" },
                "opensearch" => { "enabled" => true, "size" => "db-s-2vcpu-4gb" },
                "spaces" => { "enabled" => true, "provider" => "aws_s3" }
              }
            }
          }
        }
      ))

      config = Workspace::Services::Infra::ManifestConfiguration.new(root: root).read(environment: "production")

      assert_equal "my-product", config.fetch("app_name")
      assert_equal "sfo", config.fetch("region")
      assert_equal "sfo3", config.fetch("do_region")
      assert_equal "acme", config.fetch("github").fetch("owner")
      assert_equal "api-template", config.fetch("github").fetch("api_repo")
      assert_equal "web-template", config.fetch("github").fetch("web_repo")
      assert_equal "release", config.fetch("github").fetch("branch")
      assert_equal false, config.fetch("github").fetch("auto_deploy")
      assert_equal false, config.fetch("components").fetch("worker")
      assert_equal "db-s-2vcpu-4gb", config.fetch("sizes").fetch("opensearch")
      assert_equal "aws_s3", config.fetch("blob_store_provider")
    end
  end

  def test_read_uses_defaults_from_manifest_and_fallbacks
    Dir.mktmpdir("manifest-config-test") do |root|
      write_manifest(root, base_manifest.deep_merge(
        "project" => {
          "slug" => "fallback-slug"
        },
        "repositories" => {
          "api" => {
            "github" => "owner-from-github/api-template"
          }
        },
        "environments" => {
          "production" => {
            "infrastructure" => {}
          }
        }
      ))

      config = Workspace::Services::Infra::ManifestConfiguration.new(root: root).read(environment: "production")

      assert_equal "fallback-slug", config.fetch("app_name")
      assert_equal "nyc", config.fetch("region")
      assert_equal "nyc3", config.fetch("do_region")
      assert_equal "owner-from-github", config.fetch("github").fetch("owner")
      assert_equal "main", config.fetch("github").fetch("branch")
      assert_equal true, config.fetch("components").fetch("spaces")
      assert_equal "digitalocean_spaces", config.fetch("blob_store_provider")
    end
  end

  def test_read_prefers_project_slug_when_template_app_name_placeholder_is_present
    Dir.mktmpdir("manifest-config-test") do |root|
      write_manifest(root, base_manifest.deep_merge(
        "project" => {
          "slug" => "my-super-app"
        },
        "environments" => {
          "production" => {
            "infrastructure" => {
              "app_name" => "my-product"
            }
          }
        }
      ))

      config = Workspace::Services::Infra::ManifestConfiguration.new(root: root).read(environment: "production")

      assert_equal "my-super-app", config.fetch("app_name")
    end
  end

  def test_write_updates_manifest_infrastructure_and_opensearch_size
    Dir.mktmpdir("manifest-config-test") do |root|
      write_manifest(root, base_manifest)

      config = {
        "app_name" => "new-product",
        "region" => "nyc",
        "do_region" => "nyc3",
        "github" => {
          "owner" => "example-org",
          "branch" => "main"
        },
        "components" => {
          "api" => true,
          "worker" => true,
          "web" => true,
          "postgres" => true,
          "opensearch" => true,
          "spaces" => true
        },
        "sizes" => {
          "api" => "basic-xxs",
          "worker" => "basic-xxs",
          "web" => "basic-xxs",
          "postgres" => "db-s-1vcpu-1gb",
          "opensearch" => "db-s-1vcpu-2gb"
        },
        "blob_store_provider" => "digitalocean_spaces"
      }

      service = Workspace::Services::Infra::ManifestConfiguration.new(root: root)
      service.write(environment: "production", configuration: config)

      manifest = YAML.safe_load_file(File.join(root, "config", "project.yml"), permitted_classes: [], aliases: false)
      infra = manifest.fetch("environments").fetch("production").fetch("infrastructure")

      assert_equal "new-product", infra.fetch("app_name")
      assert_equal "nyc3", infra.fetch("region")
      assert_equal "nyc", infra.fetch("app_region")
      assert_equal "example-org", infra.fetch("github").fetch("owner")
      assert_equal "main", infra.fetch("deployment").fetch("branch")
      assert_equal "digitalocean_spaces", infra.fetch("components").fetch("spaces").fetch("provider")
      assert_equal "db-s-1vcpu-2gb", infra.fetch("components").fetch("opensearch").fetch("size")
    end
  end

  private

  def write_manifest(root, manifest)
    config_dir = File.join(root, "config")
    FileUtils.mkdir_p(config_dir)
    File.write(File.join(config_dir, "project.yml"), manifest.to_yaml)
  end

  def base_manifest
    {
      "project" => {
        "name" => "Product Template Workspace",
        "slug" => "product-template-workspace",
        "default_environment" => "production"
      },
      "repositories" => {
        "api" => {
          "purpose" => "backend-api",
          "name" => "api-template",
          "path" => "repos/api-template",
          "github" => "example-org/api-template"
        },
        "web" => {
          "purpose" => "frontend-web-client",
          "name" => "web-template",
          "path" => "repos/web-template",
          "github" => "example-org/web-template"
        }
      },
      "services" => {
        "api" => { "repository" => "api", "port" => 5001 },
        "web" => { "repository" => "web", "port" => 3000 }
      },
      "environments" => {
        "production" => {
          "infrastructure" => {}
        }
      }
    }
  end
end
