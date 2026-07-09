# frozen_string_literal: true

require "stringio"

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/commands/infra/tooling_checks"

class InfraToolingChecksTest < Minitest::Test
  def setup
    @checks = Workspace::Commands::Infra::ToolingChecks.new
  end

  def test_cli_available_returns_true_when_command_exists
    Workspace.stubs(:command_exists?).with("terraform").returns(true)
    Workspace.stubs(:ok)

    result = @checks.cli_available?(["terraform"], "Terraform CLI")

    assert_equal true, result
  end

  def test_cli_available_returns_false_when_command_missing
    Workspace.stubs(:command_exists?).with("terraform").returns(false)
    Workspace.stubs(:fail)

    result = @checks.cli_available?(["terraform"], "Terraform CLI")

    assert_equal false, result
  end

  def test_terraform_cli_available_uses_terraform_command
    @checks.expects(:cli_available?).with(["terraform"], "Terraform CLI").returns(true)

    assert_equal true, @checks.terraform_cli_available?
  end

  def test_open_tofu_cli_available_uses_tofu_command
    @checks.expects(:cli_available?).with(["tofu"], "OpenTofu CLI").returns(true)

    assert_equal true, @checks.open_tofu_cli_available?
  end

  def test_digital_ocean_cli_available_uses_doctl_command
    @checks.expects(:cli_available?).with(["doctl"], "doctl").returns(true)

    assert_equal true, @checks.digital_ocean_cli_available?
  end

  def test_github_cli_available_uses_gh_command
    @checks.expects(:cli_available?).with(["gh"], "GitHub CLI").returns(true)

    assert_equal true, @checks.github_cli_available?
  end

  def test_git_cli_available_uses_git_command
    @checks.expects(:cli_available?).with(["git"], "git").returns(true)

    assert_equal true, @checks.git_cli_available?
  end

  def test_amazon_web_services_cli_available_uses_aws_command
    @checks.expects(:cli_available?).with(["aws"], "AWS CLI").returns(true)

    assert_equal true, @checks.amazon_web_services_cli_available?
  end

  def test_digital_ocean_auth_valid_returns_false_when_doctl_missing
    Workspace.stubs(:command_exists?).with("doctl").returns(false)
    Workspace.stubs(:fail)

    assert_equal false, @checks.digital_ocean_auth_valid?
  end

  def test_digital_ocean_auth_valid_returns_true_when_doctl_auth_succeeds
    Workspace.stubs(:command_exists?).with("doctl").returns(true)
    Workspace.stubs(:capture).with("doctl account get").returns(["", true])
    Workspace.stubs(:ok)

    assert_equal true, @checks.digital_ocean_auth_valid?
  end

  def test_digital_ocean_auth_valid_returns_false_when_doctl_auth_fails
    Workspace.stubs(:command_exists?).with("doctl").returns(true)
    Workspace.stubs(:capture).with("doctl account get").returns(["failed", false])
    Workspace.stubs(:fail)

    assert_equal false, @checks.digital_ocean_auth_valid?
  end

  def test_digital_ocean_auth_valid_uses_explicit_access_token_when_provided
    Workspace.stubs(:command_exists?).with("doctl").returns(true)
    Workspace.stubs(:capture).with("doctl account get --access-token token").returns(["", true])
    Workspace.stubs(:ok)

    assert_equal true, @checks.digital_ocean_auth_valid?(access_token: "token")
  end

  def test_github_auth_valid_returns_false_when_gh_missing
    Workspace.stubs(:command_exists?).with("gh").returns(false)
    Workspace.stubs(:fail)

    assert_equal false, @checks.github_auth_valid?
  end

  def test_github_auth_valid_returns_true_when_gh_auth_succeeds
    Workspace.stubs(:command_exists?).with("gh").returns(true)
    Workspace.stubs(:capture).with("gh auth status").returns(["", true])
    Workspace.stubs(:ok)

    assert_equal true, @checks.github_auth_valid?
  end

  def test_github_auth_valid_returns_false_when_gh_auth_fails
    Workspace.stubs(:command_exists?).with("gh").returns(true)
    Workspace.stubs(:capture).with("gh auth status").returns(["failed", false])
    Workspace.stubs(:fail)

    assert_equal false, @checks.github_auth_valid?
  end
end
