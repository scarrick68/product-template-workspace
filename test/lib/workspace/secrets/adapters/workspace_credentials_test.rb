# frozen_string_literal: true

require "tmpdir"
require "active_support/encrypted_file"
require "yaml"

require_relative "../../../../test_helper"
require_relative "../../../../../lib/workspace/secrets/adapters/workspace_credentials"

class WorkspaceCredentialsAdapterTest < Minitest::Test
  def test_defaults_use_dotted_workspace_credentials_file_names
    assert_equal "workspace.credentials.key", Workspace::Secrets::Adapters::WorkspaceCredentials::DEFAULT_FILENAMES.fetch(:key)
    assert_equal "workspace.credentials.yml.enc", Workspace::Secrets::Adapters::WorkspaceCredentials::DEFAULT_FILENAMES.fetch(:encrypted)
  end

  def test_read_returns_flat_key_value
    with_adapter(payload: { "DIGITALOCEAN_ACCESS_TOKEN" => "flat-token" }) do |adapter, _|
      assert_equal "flat-token", adapter.read("DIGITALOCEAN_ACCESS_TOKEN")
    end
  end

  def test_read_returns_nested_dot_path_value
    with_adapter(payload: { "providers" => { "digitalocean" => { "token" => "nested-token" } } }) do |adapter, _|
      assert_equal "nested-token", adapter.read("providers.digitalocean.token")
    end
  end

  def test_write_updates_nested_dot_path_value
    with_adapter(payload: {}) do |adapter, encrypted_file|
      assert_equal true, adapter.write("providers.digitalocean.token", "new-token")

      data = YAML.safe_load(encrypted_file.read, permitted_classes: [], aliases: false)
      assert_equal "new-token", data.dig("providers", "digitalocean", "token")
    end
  end

  def test_write_preserves_existing_flat_key_with_dots
    with_adapter(payload: { "providers.digitalocean.token" => "old-flat" }) do |adapter, encrypted_file|
      assert_equal true, adapter.write("providers.digitalocean.token", "updated-flat")

      data = YAML.safe_load(encrypted_file.read, permitted_classes: [], aliases: false)
      assert_equal "updated-flat", data["providers.digitalocean.token"]
      assert_nil data.dig("providers", "digitalocean", "token")
    end
  end

  private

  def with_adapter(payload:)
    Dir.mktmpdir("workspace-credentials-adapter-test") do |dir|
      key_path = File.join(dir, "workspace.credentials.key")
      encrypted_path = File.join(dir, "workspace.credentials.yml.enc")

      File.write(key_path, ActiveSupport::EncryptedFile.generate_key)

      encrypted_file = ActiveSupport::EncryptedFile.new(
        content_path: encrypted_path,
        key_path: key_path,
        env_key: "UNUSED_TEST_WORKSPACE_CREDENTIALS_KEY",
        raise_if_missing_key: true
      )
      encrypted_file.write(payload.to_yaml)

      adapter = Workspace::Secrets::Adapters::WorkspaceCredentials.new(
        key_path: key_path,
        encrypted_path: encrypted_path
      )

      yield adapter, encrypted_file
    end
  end
end
