# frozen_string_literal: true

require_relative "../../../test_helper"

class PreinstallChecksCommandSmokeTest < Minitest::Test
  def test_happy_path_returns_zero
    Workspace.stubs(:required_ruby_version).returns(Gem::Version.new("3.4.0"))
    Workspace.stubs(:ruby_version).returns(Gem::Version.new("3.4.5"))
    Workspace.stubs(:ruby_compatible?).returns(true)
    Workspace.stubs(:command_exists?).returns(true)
    Workspace.stubs(:repositories).returns([{"purpose" => "data-science-ml"}])
    Workspace.stubs(:capture).returns(["gh version 2.75.0\n", true])
    Workspace.stubs(:ok)
    Workspace.stubs(:fail_with_help)

    result = Workspace::Services::PreinstallChecks.new.call
    assert_equal 0, result
  end

  def test_fails_when_uv_is_missing
    Workspace.stubs(:required_ruby_version).returns(Gem::Version.new("3.4.0"))
    Workspace.stubs(:ruby_version).returns(Gem::Version.new("3.4.5"))
    Workspace.stubs(:ruby_compatible?).returns(true)
    Workspace.stubs(:ok)
    Workspace.stubs(:fail_with_help)
    Workspace.stubs(:repositories).returns([{"purpose" => "data-science-ml"}])

    Workspace.stubs(:command_exists?).returns(true)
    Workspace.stubs(:command_exists?).with("uv").returns(false)
    Workspace.stubs(:command_exists?).with("gh").returns(true)
    Workspace.stubs(:capture).with("gh --version").returns(["gh version 2.75.0\n", true])
    Workspace.stubs(:capture).with("gh auth status").returns(["ok\n", true])

    result = Workspace::Services::PreinstallChecks.new.call
    assert_equal 1, result
  end

  def test_does_not_require_uv_when_dsml_is_not_configured
    Workspace.stubs(:required_ruby_version).returns(Gem::Version.new("3.4.0"))
    Workspace.stubs(:ruby_version).returns(Gem::Version.new("3.4.5"))
    Workspace.stubs(:ruby_compatible?).returns(true)
    Workspace.stubs(:repositories).returns([
      {"purpose" => "backend-api"},
      {"purpose" => "frontend-web-client"}
    ])
    Workspace.stubs(:ok)
    Workspace.stubs(:fail_with_help)

    Workspace.stubs(:command_exists?).returns(true)
    Workspace.stubs(:command_exists?).with("uv").returns(false)
    Workspace.stubs(:command_exists?).with("gh").returns(true)
    Workspace.stubs(:capture).with("gh --version").returns(["gh version 2.75.0\n", true])
    Workspace.stubs(:capture).with("gh auth status").returns(["ok\n", true])

    result = Workspace::Services::PreinstallChecks.new.call
    assert_equal 0, result
  end

end
