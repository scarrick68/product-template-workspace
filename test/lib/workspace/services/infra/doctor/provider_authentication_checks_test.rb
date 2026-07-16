# frozen_string_literal: true

require_relative "../../../../../test_helper"
require_relative "../../../../../../lib/workspace/services/infra/doctor/provider_authentication_checks"

class DoctorProviderAuthenticationChecksTest < Minitest::Test
  def test_to_a_builds_expected_labels
    resolver = mock("secrets_resolver")
    checks = Workspace::Services::Infra::Doctor::ProviderAuthenticationChecks.new(
      secrets_resolver: resolver,
      digitalocean_token_key: "DIGITALOCEAN_ACCESS_TOKEN"
    ).to_a

    assert_equal [
      "DIGITALOCEAN_ACCESS_TOKEN",
      "doctl auth",
      "gh auth"
    ], checks.map(&:label)
  end

  def test_digitalocean_token_check_sets_env_and_reports_available
    resolver = mock("secrets_resolver")
    checks = Workspace::Services::Infra::Doctor::ProviderAuthenticationChecks.new(
      secrets_resolver: resolver,
      digitalocean_token_key: "DIGITALOCEAN_ACCESS_TOKEN"
    ).to_a

    token_check = checks.first
    resolver.expects(:digitalocean_token).with(interactive: false).returns("token")
    Workspace.expects(:ok).with("DIGITALOCEAN_ACCESS_TOKEN: available")

    assert_equal true, token_check.call
    assert_equal "token", ENV["DIGITALOCEAN_ACCESS_TOKEN"]
  ensure
    ENV.delete("DIGITALOCEAN_ACCESS_TOKEN")
  end

  def test_doctl_auth_check_reports_invalid_auth
    resolver = mock("secrets_resolver")
    checks = Workspace::Services::Infra::Doctor::ProviderAuthenticationChecks.new(
      secrets_resolver: resolver,
      digitalocean_token_key: "DIGITALOCEAN_ACCESS_TOKEN"
    ).to_a

    doctl_check = checks[1]
    Workspace.expects(:command_exists?).with("doctl").returns(true)
    Workspace.expects(:capture).with("doctl account get").returns(["", false])
    Workspace.expects(:fail).with("doctl auth: invalid (run: doctl auth init)")

    assert_equal false, doctl_check.call
  end

  def test_gh_auth_check_reports_valid_auth
    resolver = mock("secrets_resolver")
    checks = Workspace::Services::Infra::Doctor::ProviderAuthenticationChecks.new(
      secrets_resolver: resolver,
      digitalocean_token_key: "DIGITALOCEAN_ACCESS_TOKEN"
    ).to_a

    gh_check = checks[2]
    Workspace.expects(:command_exists?).with("gh").returns(true)
    Workspace.expects(:capture).with("gh auth status").returns(["", true])
    Workspace.expects(:ok).with("gh auth: valid")

    assert_equal true, gh_check.call
  end
end
