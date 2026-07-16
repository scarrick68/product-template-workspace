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

  def test_existing_env_token_can_be_continued_and_persisted
    adapter = FakeWorkspaceAdapter.new(nil)
    prompt = mock("prompt")
    prompt.expects(:yes?).with("Use existing DigitalOcean access token from environment variable?", default: true).returns(true)
    prompt.expects(:mask).never
    prompt.expects(:say).with("Saved DIGITALOCEAN_ACCESS_TOKEN to workspace credentials.")

    resolver = Workspace::Secrets::Resolver.new(stdout: StringIO.new, stdin: TtyInput.new, workspace_adapter: adapter, prompt: prompt)

    begin
      ENV["DIGITALOCEAN_ACCESS_TOKEN"] = "env-token"
      token = resolver.digitalocean_token(interactive: true)

      assert_equal "env-token", token
      assert_equal ["DIGITALOCEAN_ACCESS_TOKEN", "env-token"], adapter.written
    ensure
      ENV.delete("DIGITALOCEAN_ACCESS_TOKEN")
    end
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
    prompt.expects(:select).with(
      "DigitalOcean access token not found. Choose how to continue:",
      ["Provide token and save to workspace credentials", "Print env var instructions"],
      default: "Provide token and save to workspace credentials"
    ).returns("Provide token and save to workspace credentials")
    prompt.expects(:mask).with("DigitalOcean access token").returns("new-token")
    prompt.expects(:say).with("Saved DIGITALOCEAN_ACCESS_TOKEN to workspace credentials.")

    resolver = Workspace::Secrets::Resolver.new(stdout: StringIO.new, stdin: TtyInput.new, workspace_adapter: adapter, prompt: prompt)

    token = resolver.digitalocean_token(interactive: true)

    assert_equal "new-token", token
    assert_equal ["DIGITALOCEAN_ACCESS_TOKEN", "new-token"], adapter.written
  end

  def test_prints_env_instructions_for_option_two
    adapter = FakeWorkspaceAdapter.new(nil)
    prompt = mock("prompt")
    prompt.expects(:select).with(
      "DigitalOcean access token not found. Choose how to continue:",
      ["Provide token and save to workspace credentials", "Print env var instructions"],
      default: "Provide token and save to workspace credentials"
    ).returns("Print env var instructions")
    prompt.expects(:mask).never
    prompt.expects(:say).with("Run:")
    prompt.expects(:say).with("export DIGITALOCEAN_ACCESS_TOKEN=your_token_here")

    resolver = Workspace::Secrets::Resolver.new(stdout: StringIO.new, stdin: TtyInput.new, workspace_adapter: adapter, prompt: prompt)

    token = resolver.digitalocean_token(interactive: true)

    assert_nil token
  end

  def test_reports_when_workspace_credentials_cannot_be_written
    ENV.delete("DIGITALOCEAN_ACCESS_TOKEN")
    adapter = FakeWorkspaceAdapter.new(nil, available: false)
    prompt = mock("prompt")
    prompt.expects(:select).with(
      "DigitalOcean access token not found. Choose how to continue:",
      ["Provide token and save to workspace credentials", "Print env var instructions"],
      default: "Provide token and save to workspace credentials"
    ).returns("Provide token and save to workspace credentials")
    prompt.expects(:mask).with("DigitalOcean access token").returns("new-token")
    prompt.expects(:say).with("Unable to save token to workspace credentials. Run: bin/workspace credentials init")

    resolver = Workspace::Secrets::Resolver.new(stdout: StringIO.new, stdin: TtyInput.new, workspace_adapter: adapter, prompt: prompt)

    token = resolver.digitalocean_token(interactive: true)

    assert_equal "new-token", token
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
