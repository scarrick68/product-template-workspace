# frozen_string_literal: true

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/secrets/workspace_credentials_store"

class WorkspaceCredentialsStoreTest < Minitest::Test
  def test_require_available_raises_when_adapter_unavailable
    adapter = Struct.new(:available?, :writable?) do
      def available? = false
      def writable? = false
    end.new

    Workspace::Secrets::Factory.stubs(:workspace_credentials_adapter).returns(adapter)
    store = Workspace::Secrets::WorkspaceCredentialsStore.new

    error = assert_raises(Workspace::Secrets::WorkspaceCredentialsStore::Error) do
      store.require_available!(message: "custom message")
    end

    assert_equal "custom message", error.message
  end

  def test_require_available_passes_when_available_and_writable
    adapter = Struct.new(:available?, :writable?) do
      def available? = true
      def writable? = true
    end.new

    Workspace::Secrets::Factory.stubs(:workspace_credentials_adapter).returns(adapter)
    store = Workspace::Secrets::WorkspaceCredentialsStore.new

    assert_nil store.require_available!
  end

  def test_read_hash_returns_hash_or_nil
    adapter = Struct.new(:value) do
      def available? = true
      def writable? = true
      def read(_key) = value
    end.new({ "email" => "ops@example.com" })

    Workspace::Secrets::Factory.stubs(:workspace_credentials_adapter).returns(adapter)
    store = Workspace::Secrets::WorkspaceCredentialsStore.new
    assert_equal({ "email" => "ops@example.com" }, store.read_hash("environments.production.application.admin"))

    adapter.value = "not-a-hash"
    assert_nil store.read_hash("environments.production.application.admin")
  end

  def test_write_hash_raises_when_write_fails
    adapter = Struct.new(:write_result) do
      def available? = true
      def writable? = true
      def write(_key, _value) = write_result
    end.new(false)

    Workspace::Secrets::Factory.stubs(:workspace_credentials_adapter).returns(adapter)
    store = Workspace::Secrets::WorkspaceCredentialsStore.new

    error = assert_raises(Workspace::Secrets::WorkspaceCredentialsStore::Error) do
      store.write_hash!("key", { "x" => "y" }, message: "write failed")
    end

    assert_equal "write failed", error.message
  end
end