# frozen_string_literal: true

require_relative "../../../../test_helper"
require_relative "../../../../../lib/workspace/infrastructure/digitalocean/resource_inventory"
require_relative "../../../../../lib/workspace/infrastructure/digitalocean/resource_purger"

class DigitalOceanResourcePurgerTest < Minitest::Test
  Resource = Workspace::Infrastructure::DigitalOcean::ResourceInventory::Resource

  def test_deletes_apps_then_databases_then_bucket_then_project
    client = mock("client")
    spaces_client = mock("spaces_client")

    sequence = sequence("purge-order")

    Workspace.expects(:info).with("Deleting app: my-super-app-api").in_sequence(sequence)
    client.expects(:run).with("apps", "delete", "app-1", "--force").in_sequence(sequence)

    Workspace.expects(:info).with("Deleting database: my-super-app-postgres").in_sequence(sequence)
    client.expects(:run).with("databases", "delete", "db-1", "--force").in_sequence(sequence)

    spaces_client.expects(:bucket_exists?).with("my-super-app-artifacts").returns(true).in_sequence(sequence)
    Workspace.expects(:info).with("Deleting Spaces bucket: my-super-app-artifacts").in_sequence(sequence)
    spaces_client.expects(:delete_bucket).with("my-super-app-artifacts").in_sequence(sequence)

    Workspace.expects(:info).with("Deleting project: my-super-app").in_sequence(sequence)
    client.expects(:run).with("projects", "delete", "proj-1", "--force").in_sequence(sequence)

    inventory = {
      project: { "id" => "proj-1", "name" => "my-super-app" },
      project_resources: [
        Resource.new(type: :app, id: "app-1", name: nil, region: nil, urn: "do:app:app-1", metadata: {}),
        Resource.new(type: :database, id: "db-1", name: nil, region: nil, urn: "do:dbaas:db-1", metadata: {}),
        Resource.new(type: :spaces_bucket, id: "my-super-app-artifacts", name: nil, region: nil, urn: "do:space:my-super-app-artifacts", metadata: {})
      ],
      matching_resources: {
        apps: [
          Resource.new(type: :app, id: "app-1", name: "my-super-app-api", region: "nyc", urn: "do:app:app-1", metadata: {})
        ],
        databases: [
          Resource.new(type: :database, id: "db-1", name: "my-super-app-postgres", region: "nyc3", urn: "do:dbaas:db-1", metadata: {})
        ]
      },
      spaces_bucket_name: "my-super-app-artifacts"
    }

    Workspace::Infrastructure::DigitalOcean::ResourcePurger.new(
      client: client,
      spaces_client: spaces_client,
      inventory: inventory
    ).call
  end

  def test_refuses_unknown_project_resource_types
    client = mock("client")
    spaces_client = mock("spaces_client")

    inventory = {
      project: { "id" => "proj-1", "name" => "my-super-app" },
      project_resources: [
        Resource.new(type: :kubernetes_cluster, id: "k8s-1", name: nil, region: nil, urn: "do:kubernetes:k8s-1", metadata: {})
      ],
      matching_resources: { apps: [], databases: [] },
      spaces_bucket_name: "my-super-app-artifacts"
    }

    error = assert_raises(Workspace::Infrastructure::DigitalOcean::Error) do
      Workspace::Infrastructure::DigitalOcean::ResourcePurger.new(
        client: client,
        spaces_client: spaces_client,
        inventory: inventory
      ).call
    end

    assert_includes error.message, "Unknown project resource types detected"
  end

  def test_deduplicates_resources_seen_in_matching_and_project_lists
    client = mock("client")
    spaces_client = mock("spaces_client")

    Workspace.expects(:info).with("Deleting app: my-super-app-api").once
    client.expects(:run).with("apps", "delete", "app-1", "--force").once

    Workspace.expects(:info).with("Deleting database: my-super-app-postgres").once
    client.expects(:run).with("databases", "delete", "db-1", "--force").once

    spaces_client.expects(:bucket_exists?).with("my-super-app-artifacts").returns(false)
    spaces_client.expects(:delete_bucket).never

    Workspace.expects(:info).with("Deleting project: my-super-app")
    client.expects(:run).with("projects", "delete", "proj-1", "--force")

    duplicate_app = Resource.new(type: :app, id: "app-1", name: nil, region: nil, urn: "do:app:app-1", metadata: {})
    duplicate_database = Resource.new(type: :database, id: "db-1", name: nil, region: nil, urn: "do:dbaas:db-1", metadata: {})

    inventory = {
      project: { "id" => "proj-1", "name" => "my-super-app" },
      project_resources: [duplicate_app, duplicate_database],
      matching_resources: {
        apps: [
          Resource.new(type: :app, id: "app-1", name: "my-super-app-api", region: "nyc", urn: "do:app:app-1", metadata: {})
        ],
        databases: [
          Resource.new(type: :database, id: "db-1", name: "my-super-app-postgres", region: "nyc3", urn: "do:dbaas:db-1", metadata: {})
        ]
      },
      spaces_bucket_name: "my-super-app-artifacts"
    }

    Workspace::Infrastructure::DigitalOcean::ResourcePurger.new(
      client: client,
      spaces_client: spaces_client,
      inventory: inventory
    ).call
  end

  def test_skips_bucket_checks_when_bucket_name_is_blank
    client = mock("client")
    spaces_client = mock("spaces_client")

    spaces_client.expects(:bucket_exists?).never
    spaces_client.expects(:delete_bucket).never

    Workspace.expects(:info).with("Deleting project: my-super-app")
    client.expects(:run).with("projects", "delete", "proj-1", "--force")

    inventory = {
      project: { "id" => "proj-1", "name" => "my-super-app" },
      project_resources: [],
      matching_resources: { apps: [], databases: [] },
      spaces_bucket_name: "  "
    }

    Workspace::Infrastructure::DigitalOcean::ResourcePurger.new(
      client: client,
      spaces_client: spaces_client,
      inventory: inventory
    ).call
  end
end
