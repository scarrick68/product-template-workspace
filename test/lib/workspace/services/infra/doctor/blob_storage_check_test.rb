# frozen_string_literal: true

require_relative "../../../../../test_helper"
require_relative "../../../../../../lib/workspace/services/infra/doctor/blob_storage_check"

class DoctorBlobStorageCheckTest < Minitest::Test
  def test_label_and_call_returns_true_when_spaces_disabled
    manifest_configuration = mock("manifest_configuration")
    secrets_resolver = mock("secrets_resolver")
    manifest_configuration.expects(:read).with(environment: "production").returns(
      {
        "components" => { "spaces" => false },
        "blob_store_provider" => "aws_s3"
      }
    )

    check = Workspace::Services::Infra::Doctor::BlobStorageCheck.new(
      manifest_configuration: manifest_configuration,
      environment: "production",
      secrets_resolver: secrets_resolver
    )

    assert_equal "blob store readiness", check.label
    assert_equal true, check.call
  end

  def test_call_checks_aws_cli_and_auth_when_provider_is_aws_s3
    manifest_configuration = mock("manifest_configuration")
    secrets_resolver = mock("secrets_resolver")
    manifest_configuration.expects(:read).with(environment: "production").returns(
      {
        "components" => { "spaces" => true },
        "blob_store_provider" => "aws_s3"
      }
    )

    check = Workspace::Services::Infra::Doctor::BlobStorageCheck.new(
      manifest_configuration: manifest_configuration,
      environment: "production",
      secrets_resolver: secrets_resolver
    )

    Workspace.expects(:info).with("blob storage provider aws_s3: checking CLI/auth readiness")
    Workspace.expects(:command_exists?).with("aws").returns(true)
    Workspace.expects(:capture).with("aws sts get-caller-identity").returns(["", true])
    Workspace.expects(:ok).with("AWS auth: valid")

    assert_equal true, check.call
  end

  def test_call_reports_missing_aws_cli
    manifest_configuration = mock("manifest_configuration")
    secrets_resolver = mock("secrets_resolver")
    manifest_configuration.expects(:read).with(environment: "production").returns(
      {
        "components" => { "spaces" => true },
        "blob_store_provider" => "aws_s3"
      }
    )

    check = Workspace::Services::Infra::Doctor::BlobStorageCheck.new(
      manifest_configuration: manifest_configuration,
      environment: "production",
      secrets_resolver: secrets_resolver
    )

    Workspace.expects(:info).with("blob storage provider aws_s3: checking CLI/auth readiness")
    Workspace.expects(:command_exists?).with("aws").returns(false)
    Workspace.expects(:fail).with("AWS CLI: missing (checked aws)")

    assert_equal false, check.call
  end

  def test_call_checks_spaces_credentials_for_digitalocean_spaces_provider
    manifest_configuration = mock("manifest_configuration")
    secrets_resolver = mock("secrets_resolver")
    manifest_configuration.expects(:read).with(environment: "production").returns(
      {
        "components" => { "spaces" => true },
        "blob_store_provider" => "digitalocean_spaces"
      }
    )

    secrets_resolver.expects(:spaces_access_key_id).with(interactive: false).returns("spaces-key")
    secrets_resolver.expects(:spaces_secret_access_key).with(interactive: false).returns("spaces-secret")

    check = Workspace::Services::Infra::Doctor::BlobStorageCheck.new(
      manifest_configuration: manifest_configuration,
      environment: "production",
      secrets_resolver: secrets_resolver
    )

    Workspace.expects(:ok).with("blob storage provider 'digitalocean_spaces': credentials available")

    assert_equal true, check.call
  end

  def test_call_reports_missing_spaces_credentials_for_digitalocean_spaces_provider
    manifest_configuration = mock("manifest_configuration")
    secrets_resolver = mock("secrets_resolver")
    manifest_configuration.expects(:read).with(environment: "production").returns(
      {
        "components" => { "spaces" => true },
        "blob_store_provider" => "digitalocean_spaces"
      }
    )

    secrets_resolver.expects(:spaces_access_key_id).with(interactive: false).returns("")
    secrets_resolver.expects(:spaces_secret_access_key).with(interactive: false).returns("")

    check = Workspace::Services::Infra::Doctor::BlobStorageCheck.new(
      manifest_configuration: manifest_configuration,
      environment: "production",
      secrets_resolver: secrets_resolver
    )

    Workspace.expects(:fail).with(
      "blob storage provider 'digitalocean_spaces': missing TEST_SPACES_ACCESS_KEY_ID and TEST_SPACES_SECRET_ACCESS_KEY in workspace credentials"
    )

    assert_equal false, check.call
  end
end
