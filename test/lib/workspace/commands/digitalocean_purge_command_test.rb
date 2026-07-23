# frozen_string_literal: true

require "stringio"

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/commands/infra/digitalocean_purge_command"

class DigitaloceanPurgeCommandTest < Minitest::Test
  Resource = Struct.new(:type, :name, :id, :region, :urn)

  def test_requires_yes_flag_for_non_interactive_execution
    command = Workspace::Commands::Infra::DigitaloceanPurgeCommand.new(["--confirm-project=my-super-app"], stdin: StringIO.new)
    command.stubs(:export_digitalocean_token!).returns(true)

    inventory = sample_inventory
    inventory_service = mock("inventory_service")
    inventory_service.expects(:call).returns(inventory)
    command.expects(:build_inventory).with(environment: "production").returns(inventory_service)
    command.expects(:build_purger).never

    Workspace.stubs(:section)
    Workspace.stubs(:warn)
    Workspace.stubs(:info)
    Workspace.expects(:fail_with_help).with(
      "DigitalOcean purge requires explicit --yes confirmation.",
      has_key(:fixes)
    )

    assert_equal 1, command.call
  end

  def test_runs_purge_non_interactive_when_confirm_project_and_yes_are_provided
    command = Workspace::Commands::Infra::DigitaloceanPurgeCommand.new(
      ["--confirm-project=my-super-app", "--yes"],
      stdin: StringIO.new
    )
    command.stubs(:export_digitalocean_token!).returns(true)

    inventory = sample_inventory
    inventory_service = mock("inventory_service")
    inventory_service.expects(:call).returns(inventory)
    command.expects(:build_inventory).with(environment: "production").returns(inventory_service)

    purger = mock("purger")
    purger.expects(:call)
    command.expects(:build_purger).with(environment: "production", inventory: inventory).returns(purger)
    command.expects(:report_remaining).with(environment: "production")

    Workspace.stubs(:section)
    Workspace.stubs(:warn)
    Workspace.stubs(:info)
    Workspace.expects(:ok).with("DigitalOcean resources deleted.")

    assert_equal 0, command.call
  end

  def test_interactive_mode_accepts_typed_yes
    stdin = StringIO.new
    def stdin.tty?
      true
    end

    prompt = mock("prompt")
    prompt.expects(:ask).with("Type \"my-super-app\" to delete these resources:").returns("my-super-app")
    prompt.expects(:ask).with("DANGER: This will permanently delete infra resources. Type 'yes' to continue:").returns("yes")

    command = Workspace::Commands::Infra::DigitaloceanPurgeCommand.new([], stdin: stdin, prompt: prompt)
    command.stubs(:export_digitalocean_token!).returns(true)

    inventory = sample_inventory
    inventory_service = mock("inventory_service")
    inventory_service.expects(:call).returns(inventory)
    command.expects(:build_inventory).with(environment: "production").returns(inventory_service)

    purger = mock("purger")
    purger.expects(:call)
    command.expects(:build_purger).with(environment: "production", inventory: inventory).returns(purger)
    command.expects(:report_remaining).with(environment: "production")

    Workspace.stubs(:section)
    Workspace.stubs(:warn)
    Workspace.stubs(:info)
    Workspace.expects(:ok).with("DigitalOcean resources deleted.")

    assert_equal 0, command.call
  end

  private

  def sample_inventory
    {
      project: { "id" => "proj-1", "name" => "my-super-app" },
      project_resources: [
        Resource.new(:app, "my-super-app-api", "app-1", "nyc", "do:app:app-1")
      ],
      matching_resources: {
        apps: [Resource.new(:app, "my-super-app-api", "app-1", "nyc", "do:app:app-1")],
        databases: []
      },
      spaces_bucket_name: "my-super-app-artifacts"
    }
  end
end
