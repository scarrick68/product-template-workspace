# frozen_string_literal: true

require_relative "../../../test_helper"

class StartDayCommandSmokeTest < Minitest::Test
  def test_happy_path_without_dev_returns_zero
    Workspace.stubs(:script_path).returns("bin/step")
    Workspace.stubs(:ok)
    Workspace.stubs(:fail_with_help)

    command = Workspace::Commands::StartDayCommand.new([])
    command.stubs(:system).returns(true)

    result = command.call
    assert_equal 0, result
  end
end
