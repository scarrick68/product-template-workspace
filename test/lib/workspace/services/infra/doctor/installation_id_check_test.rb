# frozen_string_literal: true

require_relative "../../../../../test_helper"
require_relative "../../../../../../lib/workspace/services/infra/doctor/installation_id_check"

class DoctorInstallationIdCheckTest < Minitest::Test
  def test_label_and_call_returns_true_when_installation_id_is_valid
    manifest_configuration = mock("manifest_configuration")
    manifest_configuration.expects(:read).with(environment: "production").returns(
      { "installation_id" => "a91d7c" }
    )

    check = Workspace::Services::Infra::Doctor::InstallationIdCheck.new(
      manifest_configuration: manifest_configuration,
      environment: "production"
    )

    Workspace.expects(:ok).with("project installation_id: a91d7c")

    assert_equal "project installation_id", check.label
    assert_equal true, check.call
  end

  def test_call_returns_false_when_installation_id_missing
    manifest_configuration = mock("manifest_configuration")
    manifest_configuration.expects(:read).with(environment: "production").returns({})

    check = Workspace::Services::Infra::Doctor::InstallationIdCheck.new(
      manifest_configuration: manifest_configuration,
      environment: "production"
    )

    Workspace.expects(:fail).with("project installation_id: missing")

    assert_equal false, check.call
  end

  def test_call_returns_false_when_installation_id_invalid
    manifest_configuration = mock("manifest_configuration")
    manifest_configuration.expects(:read).with(environment: "production").returns(
      { "installation_id" => "ABC123" }
    )

    check = Workspace::Services::Infra::Doctor::InstallationIdCheck.new(
      manifest_configuration: manifest_configuration,
      environment: "production"
    )

    Workspace.expects(:fail).with(
      "project installation_id: invalid (expected six lowercase hexadecimal characters)"
    )

    assert_equal false, check.call
  end
end
