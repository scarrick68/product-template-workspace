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
end
