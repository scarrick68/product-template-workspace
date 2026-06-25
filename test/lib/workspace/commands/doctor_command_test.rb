# frozen_string_literal: true

require_relative "../../../test_helper"

class DoctorCommandSmokeTest < Minitest::Test
  def test_happy_path_returns_zero
    Workspace.stubs(:command_exists?).returns(true)
    Workspace.stubs(:ports).returns({})
    Workspace.stubs(:capture).returns(["ok\n", true])
    Workspace.stubs(:ok)
    Workspace.stubs(:warn)
    Workspace.stubs(:fail_with_help)

    result = Workspace::Commands::DoctorCommand.new.call
    assert_equal 0, result
  end

  def test_missing_optional_tools_warns_but_returns_zero
    Workspace.stubs(:ports).returns({})
    Workspace.stubs(:ok)
    Workspace.stubs(:fail_with_help)

    Workspace.stubs(:command_exists?).with("ruby").returns(true)
    Workspace.stubs(:command_exists?).with("node").returns(true)
    Workspace.stubs(:command_exists?).with("npm").returns(true)
    Workspace.stubs(:command_exists?).with("docker").returns(true)
    Workspace.stubs(:command_exists?).with("gh").returns(true)
    Workspace.stubs(:command_exists?).with("mise").returns(false)
    Workspace.stubs(:command_exists?).with("psql").returns(false)

    Workspace.stubs(:capture).returns(["ok\n", true])

    Workspace.expects(:warn).with("mise is not installed. Any Ruby 4+ installation is acceptable for workspace scripts.")
    Workspace.expects(:warn).with("Postgres client (psql) is not installed or not running. This is optional because the API project may use a Docker-managed Postgres container internally. But you must do one of the following: install psql, run Postgres in Docker, or configure your API project to use a different database.")

    result = Workspace::Commands::DoctorCommand.new.call
    assert_equal 0, result
  end

  def test_missing_required_tool_returns_one
    Workspace.stubs(:ports).returns({})
    Workspace.stubs(:ok)
    Workspace.stubs(:warn)
    Workspace.stubs(:capture).returns(["ok\n", true])

    Workspace.stubs(:command_exists?).with("ruby").returns(false)
    Workspace.stubs(:command_exists?).with("node").returns(true)
    Workspace.stubs(:command_exists?).with("npm").returns(true)
    Workspace.stubs(:command_exists?).with("docker").returns(true)
    Workspace.stubs(:command_exists?).with("gh").returns(true)
    Workspace.stubs(:command_exists?).with("mise").returns(true)
    Workspace.stubs(:command_exists?).with("psql").returns(true)

    Workspace.expects(:fail_with_help).at_least_once

    result = Workspace::Commands::DoctorCommand.new.call
    assert_equal 1, result
  end
end
