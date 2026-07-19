# frozen_string_literal: true

require_relative "../../../../test_helper"
require_relative "../../../../../lib/workspace/infrastructure/digitalocean/resource_inventory"

class DigitalOceanResourceInventoryTest < Minitest::Test
  def test_collects_project_and_matching_account_resources
    client = mock("client")

    client.expects(:json).with("account", "get").returns([
      { "email" => "ops@example.com", "status" => "active" }
    ])

    client.expects(:json).with("projects", "list").returns([
      { "id" => "proj-1", "name" => "my-super-app" }
    ])

    client.expects(:json).with("projects", "resources", "list", "proj-1").returns([
      { "urn" => "do:app:app-1", "status" => "ok", "assigned_at" => "2026-01-01" },
      { "urn" => "do:space:my-super-app-artifacts", "status" => "ok", "assigned_at" => "2026-01-01" }
    ])

    client.expects(:json).with("apps", "list").returns([
      { "id" => "app-1", "spec" => { "name" => "my-super-app-api" }, "region" => { "slug" => "nyc" } },
      { "id" => "app-2", "spec" => { "name" => "my-super-app-old" }, "region" => { "slug" => "nyc" } }
    ])

    client.expects(:json).with("databases", "list").returns([
      { "id" => "db-1", "name" => "my-super-app-postgres", "region" => "nyc3", "engine" => "pg", "status" => "online" },
      { "id" => "db-2", "name" => "my-super-app-2", "region" => "nyc3", "engine" => "pg", "status" => "online" }
    ])

    inventory = Workspace::Infrastructure::DigitalOcean::ResourceInventory.new(
      client: client,
      project_name: "my-super-app",
      expected_names: ["my-super-app-api", "my-super-app-web", "my-super-app-postgres", "my-super-app-opensearch"],
      spaces_bucket_name: "my-super-app-artifacts"
    ).call

    assert_equal "ops@example.com", inventory.fetch(:account).fetch("email")
    assert_equal "my-super-app", inventory.fetch(:project).fetch("name")
    assert_equal 2, inventory.fetch(:project_resources).size
    assert_equal :spaces_bucket, inventory.fetch(:project_resources).last.type

    matching_apps = inventory.fetch(:matching_resources).fetch(:apps)
    assert_equal ["my-super-app-api"], matching_apps.map(&:name)

    matching_databases = inventory.fetch(:matching_resources).fetch(:databases)
    assert_equal ["my-super-app-postgres"], matching_databases.map(&:name)
  end
end
