# frozen_string_literal: true

require "stringio"

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/secrets/factory"
require_relative "../../../../lib/workspace/secrets/resolver"

class SecretsResolverTest < Minitest::Test
  class FakeWorkspaceAdapter
    attr_reader :written

    def initialize(value = nil, available: true, writable: true)
      @value = value
      @available = available
      @writable = writable
      @written = nil
    end

    def available?
      @available
    end

    def writable?
      @writable
    end

    def read(_key)
      @value
    end

    def write(key, value)
      @written = [key, value]
      @value = value
      true
    end

    def name
      "workspace credentials"
    end
  end

  class TtyInput < StringIO
    def tty?
      true
    end
  end

  def test_returns_workspace_token_noninteractive
    adapter = FakeWorkspaceAdapter.new("workspace-token")
    prompt = mock("prompt")
    prompt.expects(:yes?).never
    prompt.expects(:select).never
    prompt.expects(:mask).never
    prompt.expects(:say).never
    resolver = Workspace::Secrets::Resolver.new(stdout: StringIO.new, stdin: StringIO.new, workspace_adapter: adapter, prompt: prompt)

    assert_equal "workspace-token", resolver.digitalocean_token(interactive: false)
  end

  def test_returns_nil_noninteractive_when_workspace_token_missing
    adapter = FakeWorkspaceAdapter.new(nil)
    prompt = mock("prompt")
    prompt.expects(:yes?).never
    prompt.expects(:mask).never
    prompt.expects(:say).never

    resolver = Workspace::Secrets::Resolver.new(stdout: StringIO.new, stdin: StringIO.new, workspace_adapter: adapter, prompt: prompt)

    assert_nil resolver.digitalocean_token(interactive: false)
  end

  def test_existing_workspace_token_can_be_replaced
    adapter = FakeWorkspaceAdapter.new("workspace-token")
    prompt = mock("prompt")
    prompt.expects(:yes?).with("Use existing DigitalOcean access token from workspace credentials?", default: true).returns(false)
    prompt.expects(:mask).with("DigitalOcean access token").returns("replacement-token")
    prompt.expects(:say).with("Saved DIGITALOCEAN_ACCESS_TOKEN to workspace credentials.")

    resolver = Workspace::Secrets::Resolver.new(stdout: StringIO.new, stdin: TtyInput.new, workspace_adapter: adapter, prompt: prompt)

    token = resolver.digitalocean_token(interactive: true)

    assert_equal "replacement-token", token
    assert_equal ["DIGITALOCEAN_ACCESS_TOKEN", "replacement-token"], adapter.written
  end

  def test_prompts_for_token_when_missing_and_saves
    adapter = FakeWorkspaceAdapter.new(nil)
    prompt = mock("prompt")
    prompt.expects(:yes?).never
    prompt.expects(:mask).with("DigitalOcean access token").returns("new-token")
    prompt.expects(:say).with("Saved DIGITALOCEAN_ACCESS_TOKEN to workspace credentials.")

    resolver = Workspace::Secrets::Resolver.new(stdout: StringIO.new, stdin: TtyInput.new, workspace_adapter: adapter, prompt: prompt)

    token = resolver.digitalocean_token(interactive: true)

    assert_equal "new-token", token
    assert_equal ["DIGITALOCEAN_ACCESS_TOKEN", "new-token"], adapter.written
  end

  def test_returns_nil_when_prompted_token_is_blank
    adapter = FakeWorkspaceAdapter.new(nil)
    prompt = mock("prompt")
    prompt.expects(:yes?).never
    prompt.expects(:mask).with("DigitalOcean access token").returns("")
    prompt.expects(:say).never

    resolver = Workspace::Secrets::Resolver.new(stdout: StringIO.new, stdin: TtyInput.new, workspace_adapter: adapter, prompt: prompt)

    token = resolver.digitalocean_token(interactive: true)

    assert_nil token
  end

  def test_reports_when_workspace_credentials_cannot_be_written
    adapter = FakeWorkspaceAdapter.new(nil, available: false)
    prompt = mock("prompt")
    prompt.expects(:yes?).never
    prompt.expects(:mask).with("DigitalOcean access token").returns("new-token")
    prompt.expects(:say).with("Unable to save token to workspace credentials. Run: bin/workspace credentials init")

    resolver = Workspace::Secrets::Resolver.new(stdout: StringIO.new, stdin: TtyInput.new, workspace_adapter: adapter, prompt: prompt)

    token = resolver.digitalocean_token(interactive: true)

    assert_equal "new-token", token
  end

  def test_spaces_access_key_id_prefers_workspace_value
    adapter = FakeWorkspaceAdapter.new("spaces-id")
    prompt = mock("prompt")
    prompt.expects(:ask).never
    prompt.expects(:mask).never
    prompt.expects(:say).never

    resolver = Workspace::Secrets::Resolver.new(stdout: StringIO.new, stdin: StringIO.new, workspace_adapter: adapter, prompt: prompt)

    assert_equal "spaces-id", resolver.spaces_access_key_id(interactive: false)
  end

  def test_spaces_secret_access_key_does_not_use_env_when_workspace_missing
    adapter = FakeWorkspaceAdapter.new(nil)
    prompt = mock("prompt")
    prompt.expects(:ask).never
    prompt.expects(:mask).never
    prompt.expects(:say).never

    resolver = Workspace::Secrets::Resolver.new(stdout: StringIO.new, stdin: StringIO.new, workspace_adapter: adapter, prompt: prompt)

    begin
      ENV["SPACES_SECRET_ACCESS_KEY"] = "env-spaces-secret"
      assert_nil resolver.spaces_secret_access_key(interactive: false)
    ensure
      ENV.delete("SPACES_SECRET_ACCESS_KEY")
    end
  end

  def test_spaces_secret_access_key_prompts_and_persists_when_missing
    adapter = FakeWorkspaceAdapter.new(nil)
    prompt = mock("prompt")
    prompt.expects(:mask).with("DigitalOcean Spaces secret access key").returns("spaces-secret")
    prompt.expects(:say).with("Saved TEST_SPACES_SECRET_ACCESS_KEY to workspace credentials.")

    resolver = Workspace::Secrets::Resolver.new(stdout: StringIO.new, stdin: TtyInput.new, workspace_adapter: adapter, prompt: prompt)

    value = resolver.spaces_secret_access_key(interactive: true)

    assert_equal "spaces-secret", value
    assert_equal ["TEST_SPACES_SECRET_ACCESS_KEY", "spaces-secret"], adapter.written
  end

  def test_persist_spaces_credentials_writes_both_values
    adapter = FakeWorkspaceAdapter.new(nil)
    prompt = mock("prompt")
    prompt.expects(:say).with("Saved TEST_SPACES_ACCESS_KEY_ID to workspace credentials.")
    prompt.expects(:say).with("Saved TEST_SPACES_SECRET_ACCESS_KEY to workspace credentials.")

    resolver = Workspace::Secrets::Resolver.new(stdout: StringIO.new, stdin: TtyInput.new, workspace_adapter: adapter, prompt: prompt)

    assert_equal true, resolver.persist_spaces_credentials(access_key_id: "id", secret_access_key: "secret")
    assert_equal ["TEST_SPACES_SECRET_ACCESS_KEY", "secret"], adapter.written
  end

  def test_factory_returns_macos_adapter_on_darwin
    adapter = Workspace::Secrets::Factory.keychain_adapter(platform: "darwin22")

    assert_instance_of Workspace::Secrets::Adapters::MacosKeychain, adapter
  end

  def test_factory_returns_unsupported_adapter_elsewhere
    adapter = Workspace::Secrets::Factory.keychain_adapter(platform: "linux-gnu")

    assert_instance_of Workspace::Secrets::Adapters::UnsupportedKeychain, adapter
  end

  def test_factory_returns_workspace_credentials_adapter
    adapter = Workspace::Secrets::Factory.workspace_credentials_adapter

    assert_instance_of Workspace::Secrets::Adapters::WorkspaceCredentials, adapter
  end
end
