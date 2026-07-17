# frozen_string_literal: true

require_relative "../../../../test_helper"
require_relative "../../../../../lib/workspace/services/infra/terraform_variables"

class TerraformVariablesTest < Minitest::Test
  def test_to_h_builds_expected_tfvars
    config = {
      "app_name" => "my-product",
      "region" => "nyc",
      "do_region" => "nyc3",
      "github" => {
        "owner" => "example-org",
        "api_repo" => "my-product-api",
        "web_repo" => "my-product-web",
        "branch" => "main"
      },
      "components" => {
        "spaces" => true
      },
      "blob_store_provider" => "digitalocean_spaces",
      "sizes" => {
        "api" => "basic-xxs",
        "worker" => "basic-xs",
        "web" => "basic-s",
        "postgres" => "db-s-1vcpu-1gb",
        "opensearch" => "db-s-1vcpu-2gb"
      }
    }

    tfvars = Workspace::Services::Infra::TerraformVariables.new(config).to_h

    assert_equal "my-product", tfvars.fetch("project_name")
    assert_equal "my-product-api", tfvars.fetch("rails_app_name")
    assert_equal "nyc", tfvars.fetch("app_region")
    assert_equal "basic-xxs", tfvars.fetch("web_instance_size_slug")
    assert_equal "basic-xs", tfvars.fetch("worker_instance_size_slug")
    assert_equal "my-product-web", tfvars.fetch("frontend_app_name")
    assert_equal "example-org/my-product-web", tfvars.fetch("frontend_repo")
    assert_equal "main", tfvars.fetch("frontend_branch")
    assert_equal "basic-s", tfvars.fetch("frontend_web_instance_size_slug")
    assert_equal "my-product-postgres", tfvars.fetch("postgres_name")
    assert_equal "nyc3", tfvars.fetch("postgres_region")
    assert_equal "db-s-1vcpu-1gb", tfvars.fetch("postgres_size")
    assert_equal "my-product-opensearch", tfvars.fetch("opensearch_name")
    assert_equal "nyc3", tfvars.fetch("opensearch_region")
    assert_equal "db-s-1vcpu-2gb", tfvars.fetch("opensearch_size")
    assert_equal true, tfvars.fetch("enable_spaces")
    assert_equal "digitalocean_spaces", tfvars.fetch("spaces_provider")
    assert_equal "nyc3", tfvars.fetch("spaces_region")
    assert_equal "my-product-artifacts", tfvars.fetch("spaces_bucket_name")
  end

  def test_to_h_requires_opensearch_size
    config = {
      "app_name" => "my-product",
      "region" => "nyc",
      "do_region" => "nyc3",
      "github" => {
        "owner" => "example-org",
        "api_repo" => "my-product-api",
        "web_repo" => "my-product-web",
        "branch" => "main"
      },
      "components" => {
        "spaces" => true
      },
      "blob_store_provider" => "digitalocean_spaces",
      "sizes" => {
        "api" => "basic-xxs",
        "worker" => "basic-xxs",
        "web" => "basic-xxs",
        "postgres" => "db-s-1vcpu-1gb"
      }
    }

    assert_raises(KeyError) do
      Workspace::Services::Infra::TerraformVariables.new(config).to_h
    end
  end
end
