# frozen_string_literal: true

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/commands/infra/tfvars_builder"

class InfraTfvarsBuilderTest < Minitest::Test
  def test_build_maps_project_and_component_defaults
    builder = Workspace::Commands::Infra::TfvarsBuilder.new(
      default_opensearch_size: "db-s-1vcpu-2gb",
      token_fetcher: -> { "token" },
      env: {
        "RAILS_MASTER_KEY" => "master-key",
        "DATA_ARTIFACT_BUCKET" => "custom-bucket"
      }
    )

    tfvars = builder.build(
      "app_name" => "my-app",
      "environment" => "production",
      "region" => "nyc",
      "do_region" => "nyc3",
      "project" => {
        "name" => "my-app-production",
        "environment" => "production",
        "purpose" => "Web Application"
      },
      "github" => {
        "owner" => "org",
        "api_repo" => "api",
        "web_repo" => "web",
        "branch" => "main"
      },
      "components" => {
        "spaces" => true
      },
      "sizes" => {}
    )

    assert_equal "token", tfvars["digitalocean_access_token"]
    assert_equal "my-app-production", tfvars["project_name"]
    assert_equal "production", tfvars["project_environment"]
    assert_equal "Web Application", tfvars["project_purpose"]
    assert_equal "custom-bucket", tfvars["data_artifact_bucket"]
    assert_equal "master-key", tfvars["rails_master_key"]
    assert_equal "db-s-1vcpu-2gb", tfvars["opensearch_size_slug"]
  end

  def test_build_uses_placeholders_when_env_and_token_missing
    builder = Workspace::Commands::Infra::TfvarsBuilder.new(
      default_opensearch_size: "db-s-1vcpu-2gb",
      token_fetcher: -> { nil },
      env: {}
    )

    tfvars = builder.build(
      "app_name" => "my-app",
      "environment" => "production",
      "region" => "nyc",
      "do_region" => "nyc3",
      "github" => {},
      "components" => {},
      "sizes" => {}
    )

    assert_equal "<set-digitalocean_access_token>", tfvars["digitalocean_access_token"]
    assert_equal "<set-rails_master_key>", tfvars["rails_master_key"]
    assert_equal "my-app-production", tfvars["project_name"]
    assert_equal "production", tfvars["project_environment"]
    assert_equal "Web Application", tfvars["project_purpose"]
  end
end
