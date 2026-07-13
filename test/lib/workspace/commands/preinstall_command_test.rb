# frozen_string_literal: true

require_relative "../../../test_helper"

class PreinstallCommandSmokeTest < Minitest::Test
  def test_happy_path_returns_zero
    Workspace.stubs(:required_ruby_version).returns(Gem::Version.new("3.4.0"))
    Workspace.stubs(:ruby_version).returns(Gem::Version.new("3.4.5"))
    Workspace.stubs(:ruby_compatible?).returns(true)
    Workspace.stubs(:command_exists?).returns(true)
    Workspace.stubs(:capture).returns(["gh version 2.75.0\n", true])
    Workspace.stubs(:ok)
    Workspace.stubs(:fail_with_help)

    result = Workspace::Services::Preinstall.new.call
    assert_equal 0, result
  end

end
