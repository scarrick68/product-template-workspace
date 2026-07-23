# frozen_string_literal: true

require "stringio"

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/commands/infra/digitalocean_resources_command"

class DigitaloceanResourcesCommandTest < Minitest::Test
  Resource = Struct.new(:type, :name, :id, :region, :urn)

  def test_reports_inventory_and_returns_zero
    command = Workspace::Commands::Infra::DigitaloceanResourcesCommand.new([])
    command.stubs(:export_digitalocean_token!).returns(true)

    inventory = {
      account: { "email" => "ops@example.com", "status" => "active" },
      project: { "id" => "proj-1", "name" => "my-super-app" },
      project_resources: [Resource.new(:app, "my-super-app-api", "app-1", "nyc", "do:app:app-1")],
      matching_resources: {
        apps: [Resource.new(:app, "my-super-app-api", "app-1", "nyc", "do:app:app-1")],
        databases: []
      },
      spaces_bucket_name: "my-super-app-artifacts"
    }

    inventory_service = mock("inventory_service")
    inventory_service.expects(:call).returns(inventory)
    command.expects(:build_inventory).with(environment: "production").returns(inventory_service)

    Workspace.stubs(:section)
    Workspace.stubs(:info)

    assert_equal 0, command.call
  end

  def test_returns_one_for_invalid_option
    stderr = StringIO.new

    command = Workspace::Commands::Infra::DigitaloceanResourcesCommand.new(["--bad-flag"], stderr: stderr)

    assert_equal 1, command.call
    assert_includes stderr.string, "Usage: bin/workspace infra digitalocean resources"
  end
end
