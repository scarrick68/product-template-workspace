# frozen_string_literal: true

require_relative "../../../../../test_helper"
require_relative "../../../../../../lib/workspace/services/infra/doctor/provider_authentication_checks"

class DoctorProviderAuthenticationChecksTest < Minitest::Test
  def test_to_a_builds_expected_labels
    credentials = mock("credentials")
    credentials.expects(:digitalocean_token_env_key).returns("DIGITALOCEAN_ACCESS_TOKEN")
    checks = Workspace::Services::Infra::Doctor::ProviderAuthenticationChecks.new(
      credentials: credentials
    ).to_a

    assert_equal [
      "DIGITALOCEAN_ACCESS_TOKEN",
      "doctl auth",
      "gh auth"
    ], checks.map(&:label)
  end

  def test_digitalocean_token_check_sets_env_and_reports_available
    credentials = mock("credentials")
    checks = Workspace::Services::Infra::Doctor::ProviderAuthenticationChecks.new(
      credentials: credentials
    ).to_a

    token_check = checks.first
    credentials.expects(:digitalocean_token_env_key).returns("DIGITALOCEAN_ACCESS_TOKEN")
    credentials.expects(:digitalocean_token_available?).returns(true)
    credentials.expects(:export_terraform_environment!).with(interactive: false).returns(true)
    Workspace.expects(:ok).with("DIGITALOCEAN_ACCESS_TOKEN: available")

    assert_equal true, token_check.call
  end

  def test_digitalocean_token_check_reports_missing
    credentials = mock("credentials")
    checks = Workspace::Services::Infra::Doctor::ProviderAuthenticationChecks.new(
      credentials: credentials
    ).to_a

    token_check = checks.first
    credentials.expects(:digitalocean_token_available?).returns(false)
    credentials.expects(:digitalocean_token_env_key).returns("DIGITALOCEAN_ACCESS_TOKEN")
    credentials.expects(:export_terraform_environment!).never
    Workspace.expects(:fail).with("DIGITALOCEAN_ACCESS_TOKEN: missing")

    assert_equal false, token_check.call
  end

  def test_doctl_auth_check_reports_invalid_auth
    credentials = mock("credentials")
    checks = Workspace::Services::Infra::Doctor::ProviderAuthenticationChecks.new(
      credentials: credentials
    ).to_a

    doctl_check = checks[1]
    Workspace.expects(:command_exists?).with("doctl").returns(true)
    Workspace.expects(:capture).with("doctl account get").returns(["", false])
    Workspace.expects(:fail).with("doctl auth: invalid (run: doctl auth init)")

    assert_equal false, doctl_check.call
  end

  def test_gh_auth_check_reports_valid_auth
    credentials = mock("credentials")
    checks = Workspace::Services::Infra::Doctor::ProviderAuthenticationChecks.new(
      credentials: credentials
    ).to_a

    gh_check = checks[2]
    Workspace.expects(:command_exists?).with("gh").returns(true)
    Workspace.expects(:capture).with("gh auth status").returns(["", true])
    Workspace.expects(:ok).with("gh auth: valid")

    assert_equal true, gh_check.call
  end
end
