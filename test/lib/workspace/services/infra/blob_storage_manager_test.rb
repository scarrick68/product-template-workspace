# frozen_string_literal: true

require "stringio"

require_relative "../../../../test_helper"
require_relative "../../../../../lib/workspace/services/infra/blob_storage_manager"

class InfraBlobStorageManagerTest < Minitest::Test
  class TtyInput < StringIO
    def tty?
      true
    end
  end

  def test_exports_spaces_env_vars_when_provider_is_digitalocean_spaces
    manifest_configuration = mock("manifest_configuration")
    manifest_configuration.expects(:read).with(environment: "production").returns(
      {
        "components" => { "spaces" => true },
        "blob_store_provider" => "digitalocean_spaces"
      }
    )

    secrets_resolver = mock("secrets_resolver")
    secrets_resolver.expects(:spaces_access_key_id).with(interactive: false).returns("key-id")
    secrets_resolver.expects(:spaces_secret_access_key).with(interactive: false).returns("secret-key")

    manager = Workspace::Services::Infra::BlobStorageManager.new(
      manifest_configuration: manifest_configuration,
      secrets_resolver: secrets_resolver,
      stdin: TtyInput.new
    )

    begin
      ENV.delete("SPACES_ACCESS_KEY_ID")
      ENV.delete("SPACES_SECRET_ACCESS_KEY")

      assert_equal true, manager.ensure_spaces_credentials_for_provisioning(environment: "production", interactive: true)
      assert_equal "key-id", ENV["SPACES_ACCESS_KEY_ID"]
      assert_equal "secret-key", ENV["SPACES_SECRET_ACCESS_KEY"]
    ensure
      ENV.delete("SPACES_ACCESS_KEY_ID")
      ENV.delete("SPACES_SECRET_ACCESS_KEY")
    end
  end

  def test_skips_when_blob_store_provider_is_not_digitalocean_spaces
    manifest_configuration = mock("manifest_configuration")
    manifest_configuration.expects(:read).with(environment: "production").returns(
      {
        "components" => { "spaces" => true },
        "blob_store_provider" => "aws_s3"
      }
    )

    secrets_resolver = mock("secrets_resolver")
    secrets_resolver.expects(:spaces_access_key_id).never
    secrets_resolver.expects(:spaces_secret_access_key).never

    manager = Workspace::Services::Infra::BlobStorageManager.new(
      manifest_configuration: manifest_configuration,
      secrets_resolver: secrets_resolver,
      stdin: StringIO.new
    )

    assert_nil manager.ensure_spaces_credentials_for_provisioning(environment: "production", interactive: true)
  end

  def test_provisions_and_persists_spaces_credentials_when_missing
    manifest_configuration = mock("manifest_configuration")
    manifest_configuration.expects(:read).with(environment: "production").returns(
      {
        "app_name" => "my-product",
        "components" => { "spaces" => true },
        "blob_store_provider" => "digitalocean_spaces"
      }
    )

    secrets_resolver = mock("secrets_resolver")
    secrets_resolver.expects(:spaces_access_key_id).with(interactive: false).returns("")
    secrets_resolver.expects(:spaces_secret_access_key).with(interactive: false).returns("")
    secrets_resolver.expects(:persist_spaces_credentials).with(
      access_key_id: "new-key-id",
      secret_access_key: "new-secret-key"
    ).returns(true)

    Workspace.expects(:info).with(
      "DigitalOcean Spaces credentials missing (TEST_SPACES_ACCESS_KEY_ID and TEST_SPACES_SECRET_ACCESS_KEY); provisioning via doctl"
    )
    Workspace.expects(:capture).with do |command|
      command.start_with?("doctl spaces keys create ") &&
        command.include?("--grants bucket=;permission=fullaccess") &&
        command.include?("--output json")
    end.returns(["[{\"access_key\":\"new-key-id\",\"secret_key\":\"new-secret-key\"}]", true])

    manager = Workspace::Services::Infra::BlobStorageManager.new(
      manifest_configuration: manifest_configuration,
      secrets_resolver: secrets_resolver,
      stdin: StringIO.new
    )

    begin
      ENV.delete("SPACES_ACCESS_KEY_ID")
      ENV.delete("SPACES_SECRET_ACCESS_KEY")

      assert_equal true, manager.ensure_spaces_credentials_for_provisioning(environment: "production", interactive: true)
      assert_equal "new-key-id", ENV["SPACES_ACCESS_KEY_ID"]
      assert_equal "new-secret-key", ENV["SPACES_SECRET_ACCESS_KEY"]
    ensure
      ENV.delete("SPACES_ACCESS_KEY_ID")
      ENV.delete("SPACES_SECRET_ACCESS_KEY")
    end
  end
end
